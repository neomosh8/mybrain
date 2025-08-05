import Foundation
import Accelerate

// MARK: - Second-Order Section Filter
private struct SOSSection {
    // Coefficients: b0, b1, b2, a0, a1, a2
    let b0: Double, b1: Double, b2: Double
    let a0: Double, a1: Double, a2: Double
    private var v1: Double, v2: Double
    
    init(coefficients sos: [Double], initialState value: Double) {
        b0 = sos[0]; b1 = sos[1]; b2 = sos[2]
        a0 = sos[3]; a1 = sos[4]; a2 = sos[5]
        v1 = value; v2 = value
    }
    
    mutating func reset(to value: Double) {
        v1 = value; v2 = value
    }
    
    mutating func apply(to data: inout [Double]) {
        for i in 0..<data.count {
            let x = data[i]
            let v = x - a1 * v1 - a2 * v2
            let y = b0 * v + b1 * v1 + b2 * v2
            v2 = v1
            v1 = v
            data[i] = y / a0
        }
    }
}

// MARK: - OnlineFilter (EEG Real-Time)
final class OnlineFilter {
    // 4th order Butterworth bandpass 0.5-40 Hz (2 SOS)
    private let bpSOS: [[Double]] = [
        [0.003621681, 0.0072433619, 0.003621681, 1.0, -1.8151128103, 0.8310055891],
        [1.0, 2.0, 1.0, 1.0, -1.1428738642, 0.4128015981]
    ]
    
    // 2nd order notch @60 Hz (1 SOS)
    private let notchSOS: [[Double]] = [
        [0.9565436765, -1.8130534305, 0.9565436765, 1.0, -1.8130534305, 0.9130873534]
    ]
    
    private var bpChainCh1: [SOSSection] = []
    private var bpChainCh2: [SOSSection] = []
    private var notchChainCh1: [SOSSection] = []
    private var notchChainCh2: [SOSSection] = []
    private var isInitialized = false
    
    /// Apply bandpass + notch filters to two channels in place
    func apply(to ch1Data: inout [Double], _ ch2Data: inout [Double]) {
        guard !ch1Data.isEmpty && !ch2Data.isEmpty else { return }
        
        if !isInitialized {
            let init1 = ch1Data[0], init2 = ch2Data[0]
            bpChainCh1 = bpSOS.map { SOSSection(coefficients: $0, initialState: init1) }
            bpChainCh2 = bpSOS.map { SOSSection(coefficients: $0, initialState: init2) }
            notchChainCh1 = notchSOS.map { SOSSection(coefficients: $0, initialState: init1) }
            notchChainCh2 = notchSOS.map { SOSSection(coefficients: $0, initialState: init2) }
            isInitialized = true
        }
        
        // Copy for processing
        var temp1 = ch1Data, temp2 = ch2Data
        // Bandpass
        for i in 0..<bpChainCh1.count { bpChainCh1[i].apply(to: &temp1); bpChainCh2[i].apply(to: &temp2) }
        // Notch
        for i in 0..<notchChainCh1.count { notchChainCh1[i].apply(to: &temp1); notchChainCh2[i].apply(to: &temp2) }
        // Update outputs
        ch1Data = temp1; ch2Data = temp2
    }
}

// MARK: - SignalProcessing
class SignalProcessing {
    internal static let sampleRate: Int = 250
    
    private static let windowSize: Int = 250
    private static let overlapFraction: Double = 0.75
    private static let powerScale: Double = 0.84
    private static let targetBin: Int = 8
    private static let noiseBand = (45.0, 100.0)
    private static let signalBands: [String: (low: Double, high: Double)] = [
        "delta": (1, 4),
        "theta": (4, 8),
        "alpha": (8, 12),
        "beta": (13, 30),
        "gamma": (30, 45)
    ]
    
    private static var leadoffCh1: [Double] = []
    private static var leadoffCh2: [Double] = []
    
    private static var fftSetupCache = [vDSP_Length: FFTSetup]()
    
    static func resetLeadoffData() {
        leadoffCh1.removeAll(); leadoffCh2.removeAll()
    }
    
    static func processLeadoffDetection(ch1Data: [Int32], ch2Data: [Int32]) -> (ch1Connected: Bool, ch2Connected: Bool, ch1Quality: Double, ch2Quality: Double) {
        let d1 = ch1Data.map(Double.init)
        let d2 = ch2Data.map(Double.init)
        let p1 = calculateWelchPower(data: d1)
        let p2 = calculateWelchPower(data: d2)
        print("Lead-off Detection - Channel Powers: CH1=\(p1), CH2=\(p2)")
        
        leadoffCh1.append(p1); leadoffCh2.append(p2)
        if leadoffCh1.count > 100 { leadoffCh1.removeFirst(leadoffCh1.count - 100) }
        if leadoffCh2.count > 100 { leadoffCh2.removeFirst(leadoffCh2.count - 100) }
        
        let conn1 = checkConnection(data: leadoffCh1)
        let conn2 = checkConnection(data: leadoffCh2)
        let qual1 = calculateQuality(data: leadoffCh1)
        let qual2 = calculateQuality(data: leadoffCh2)
        return (conn1, conn2, qual1, qual2)
    }
    
    private static func calculateWelchPower(data: [Double]) -> Double {
        guard data.count >= windowSize else {
            if data.isEmpty { return 0.0 }
            var msq: Double = 0
            vDSP_measqvD(data, 1, &msq, vDSP_Length(data.count))
            return msq * powerScale
        }
        let windowData = Array(data.suffix(windowSize))
        
        let log2n = vDSP_Length(log2(Double(windowSize)))
        guard let fftSetup = fftSetup(for: windowSize) else { return 0 }

        var win = [Double](repeating: 0, count: windowSize)
        vDSP_hann_windowD(&win, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        var windowed = [Double](repeating: 0, count: windowSize)
        vDSP_vmulD(windowData, 1, win, 1, &windowed, 1, vDSP_Length(windowSize))
        
        var real = windowed, imag = [Double](repeating: 0, count: windowSize)
        var spectrum = [Double](repeating: 0, count: windowSize/2)
        real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPDoubleSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_fft_zipD(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmagsD(&split, 1, &spectrum, 1, vDSP_Length(windowSize/2))
            }
        }
        var scale = 2.0 / (Double(sampleRate) * Double(windowSize))
        vDSP_vsmulD(spectrum, 1, &scale, &spectrum, 1, vDSP_Length(spectrum.count))
        return spectrum[min(targetBin, spectrum.count-1)]
    }
    
    private static func removeOutliers(from data: [Double]) -> [Double] {
        guard data.count > 4 else { return data }
        let sorted = data.sorted()
        let q1 = sorted[data.count/4]
        let q3 = sorted[(data.count*3)/4]
        let iqr = q3 - q1
        guard iqr != 0 else { return data }
        let lower = q1 - 1.5*iqr, upper = q3 + 1.5*iqr
        return data.filter { $0 >= lower && $0 <= upper }
    }
    
    private static func checkConnection(data: [Double]) -> Bool {
        guard data.count > 20 else { return false }
        let baselineCount = min(data.count/2, 50)
        let baseline = removeOutliers(from: Array(data.prefix(baselineCount)))
        let recent = Array(data.suffix(5))
        guard !baseline.isEmpty && !recent.isEmpty else { return false }
        
        let meanBase = baseline.reduce(0, +) / Double(baseline.count)
        let meanRecent = recent.reduce(0, +) / Double(recent.count)
        let stdBase = calculateStd(data: baseline, mean: meanBase)
        let threshold = meanBase + 2*stdBase
        return meanRecent > threshold
    }
    
    private static func calculateQuality(data: [Double]) -> Double {
        guard data.count >= 5 else { return 0.0 }
        
        let recent = Array(data.suffix(min(10, data.count)))
        let clean = removeOutliers(from: recent)
        guard clean.count >= 3 else { return 0 }
        let mean = clean.reduce(0, +) / Double(clean.count)
        guard abs(mean) > .ulpOfOne else { return 50 }
        let std = calculateStd(data: clean, mean: mean)
        let cv = std / abs(mean)
        return max(0, min(100, 100 * (1 - cv)))
    }
    
    private static func calculateStd(data: [Double], mean: Double) -> Double {
        let count = data.count
        guard count > 1 else { return 0.0 }
        let varSum = data.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sqrt(varSum / Double(count - 1))
    }
    
    private static func fftSetup(for length: Int) -> FFTSetup? {
        let log2n = vDSP_Length(log2(Double(length)))
        if let existing = fftSetupCache[log2n] {
            return existing
        }
        guard let newSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        fftSetupCache[log2n] = newSetup
        return newSetup
    }
    
    // MARK: - Private Quality Analysis Methods
    
    static func calculateQualityMetrics(for data: [Double]) -> SignalQualityMetrics? {
        // Calculate dynamic range
        let dr = calculateDynamicRange(data)
        
        // Calculate SNR using Welch's method
        let snr = calculateSNR(data)
        
        return SignalQualityMetrics(dynamicRange: dr, snr: snr)
    }
    
    private static func calculateDynamicRange(_ data: [Double]) -> DynamicRange {
        guard !data.isEmpty else {
            return DynamicRange(linear: 0, db: 0, peakToPeak: 0, rms: 0, max: 0, min: 0)
        }
        
        // Remove DC component
        var mean: Double = 0
        vDSP_meanvD(data, 1, &mean, vDSP_Length(data.count))
        let signalAC = data.map { $0 - mean }
        
        // Peak-to-peak dynamic range
        var max: Double = 0
        var min: Double = 0
        vDSP_maxvD(signalAC, 1, &max, vDSP_Length(signalAC.count))
        vDSP_minvD(signalAC, 1, &min, vDSP_Length(signalAC.count))
        let peakToPeak = max - min
        
        // RMS value
        var rms: Double = 0
        vDSP_measqvD(signalAC, 1, &rms, vDSP_Length(signalAC.count))
        rms = sqrt(rms)
        
        // Dynamic range in dB
        let absValues = signalAC.map { abs($0) }
        var maxAbs: Double = 0
        var minAbs: Double = 0
        vDSP_maxvD(absValues, 1, &maxAbs, vDSP_Length(absValues.count))
        
        // Find minimum non-zero value
        let nonZeroValues = absValues.filter { $0 > 0 }
        if !nonZeroValues.isEmpty {
            vDSP_minvD(nonZeroValues, 1, &minAbs, vDSP_Length(nonZeroValues.count))
        } else {
            minAbs = 1e-10
        }
        
        let drDB = minAbs > 0 ? 20 * log10(maxAbs / minAbs) : 0
        let linear = minAbs > 0 ? maxAbs / minAbs : 0
        
        return DynamicRange(
            linear: linear,
            db: drDB,
            peakToPeak: peakToPeak,
            rms: rms,
            max: maxAbs,
            min: minAbs
        )
    }
    
    private static func calculateSNR(_ data: [Double]) -> SignalToNoiseRatio {
        guard data.count >= sampleRate else {
            return SignalToNoiseRatio(
                totalSNRdB: 0,
                bandSNR: [:],
                signalPower: 0,
                noisePower: 0
            )
        }
        
        // Calculate power spectral density using Welch's method
        let nperseg = min(data.count / 4, sampleRate)
        let (freqs, psd) = welch(data, fs: Double(sampleRate), nperseg: nperseg)
        
        // Calculate power in signal bands
        var signalPower: Double = 0
        var bandSNR: [String: Double] = [:]
        
        for (bandName, (low, high)) in signalBands {
            let bandPower = calculateBandPower(freqs: freqs, psd: psd, lowFreq: low, highFreq: high)
            signalPower += bandPower
            bandSNR[bandName] = bandPower
        }
        
        // Calculate noise power
        let noisePower = calculateBandPower(
            freqs: freqs,
            psd: psd,
            lowFreq: noiseBand.0,
            highFreq: noiseBand.1
        )
        
        // Total SNR
        let totalSNRdB = noisePower > 0 ? 10 * log10(signalPower / noisePower) : 0
        
        // Band-specific SNR
        for bandName in bandSNR.keys {
            if let bandPower = bandSNR[bandName], noisePower > 0 {
                bandSNR[bandName] = 10 * log10(bandPower / noisePower)
            } else {
                bandSNR[bandName] = 0
            }
        }
        
        return SignalToNoiseRatio(
            totalSNRdB: totalSNRdB,
            bandSNR: bandSNR,
            signalPower: signalPower,
            noisePower: noisePower
        )
    }
    
    private static func welch(_ data: [Double], fs: Double, nperseg: Int) -> (freqs: [Double], psd: [Double]) {
        let noverlap = nperseg / 2
        let step = nperseg - noverlap
        
        var psdAccumulator = [Double](repeating: 0, count: nperseg / 2 + 1)
        var segmentCount = 0
        
        // Create FFT setup once
        let log2n = vDSP_Length(log2(Double(nperseg)))
        guard let fftSetup = fftSetup(for: nperseg) else { return ([], []) }

        // Process overlapping segments
        for start in stride(from: 0, to: data.count - nperseg + 1, by: step) {
            let segment = Array(data[start..<start + nperseg])
            
            // Apply Hann window
            var windowedSegment = [Double](repeating: 0, count: nperseg)
            var window = [Double](repeating: 0, count: nperseg)
            vDSP_hann_windowD(&window, vDSP_Length(nperseg), Int32(vDSP_HANN_NORM))
            vDSP_vmulD(segment, 1, window, 1, &windowedSegment, 1, vDSP_Length(nperseg))
            
            // Compute FFT and PSD
            var realPart = windowedSegment
            var imagPart = [Double](repeating: 0, count: nperseg)
            var segmentPSD = [Double](repeating: 0, count: nperseg / 2 + 1)
            
            realPart.withUnsafeMutableBufferPointer { realBuffer in
                imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                    var splitComplex = DSPDoubleSplitComplex(
                        realp: realBuffer.baseAddress!,
                        imagp: imagBuffer.baseAddress!
                    )
                    
                    // Perform FFT
                    vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Calculate power spectrum
                    vDSP_zvmagsD(&splitComplex, 1, &segmentPSD, 1, vDSP_Length(nperseg / 2))
                }
            }
            
            // Handle DC component
            segmentPSD[0] = realPart[0] * realPart[0]
            
            // Scale
            var scale = 2.0 / (fs * Double(nperseg))
            vDSP_vsmulD(segmentPSD, 1, &scale, &segmentPSD, 1, vDSP_Length(segmentPSD.count))
            segmentPSD[0] /= 2.0
            
            // Accumulate
            vDSP_vaddD(psdAccumulator, 1, segmentPSD, 1, &psdAccumulator, 1, vDSP_Length(segmentPSD.count))
            segmentCount += 1
        }
        
        // Average
        var scale = 1.0 / Double(segmentCount)
        vDSP_vsmulD(psdAccumulator, 1, &scale, &psdAccumulator, 1, vDSP_Length(psdAccumulator.count))
        
        // Generate frequency array
        let freqs = (0..<psdAccumulator.count).map { Double($0) * fs / Double(nperseg) }
        
        return (freqs, psdAccumulator)
    }
    
    private static func computePSD(_ segment: [Double], fs: Double) -> [Double] {
        let n = segment.count
        let log2n = vDSP_Length(log2(Double(n)))
        guard let fftSetup = fftSetup(for: n) else { return [Double](repeating: 0, count: n / 2 + 1) }
        
        // Prepare for FFT
        var realPart = segment
        var imagPart = [Double](repeating: 0, count: n)
        var powerSpectrum = [Double](repeating: 0, count: n / 2 + 1)
        
        // Use withUnsafeMutablePointer to ensure pointer validity
        realPart.withUnsafeMutableBufferPointer { realBuffer in
            imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )
                
                // Perform FFT
                vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate power spectrum
                vDSP_zvmagsD(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(n / 2))
            }
        }
        
        // Handle DC and Nyquist
        powerSpectrum[0] = realPart[0] * realPart[0]
        if n % 2 == 0 {
            powerSpectrum[n / 2] = realPart[n / 2] * realPart[n / 2]
        }
        
        // Scale for PSD
        var scale = 2.0 / (fs * Double(n))
        vDSP_vsmulD(powerSpectrum, 1, &scale, &powerSpectrum, 1, vDSP_Length(powerSpectrum.count))
        
        // DC and Nyquist don't get doubled
        powerSpectrum[0] /= 2.0
        if n % 2 == 0 {
            powerSpectrum[n / 2] /= 2.0
        }
        
        return powerSpectrum
    }
    
    private static func calculateBandPower(freqs: [Double], psd: [Double], lowFreq: Double, highFreq: Double) -> Double {
        var power: Double = 0
        
        for i in 0..<freqs.count {
            if freqs[i] >= lowFreq && freqs[i] <= highFreq {
                if i > 0 {
                    // Trapezoidal integration
                    let df = freqs[i] - freqs[i-1]
                    power += (psd[i] + psd[i-1]) * df / 2.0
                }
            }
        }
        
        return power
    }
    
}
