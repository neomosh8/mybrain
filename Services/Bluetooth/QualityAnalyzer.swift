import Foundation
import Accelerate
import Combine

// MARK: - Quality Analysis Data Structures
struct SignalQualityMetrics {
    let dynamicRange: DynamicRange
    let snr: SignalToNoiseRatio
}

struct DynamicRange {
    let linear: Double
    let db: Double
    let peakToPeak: Double
    let rms: Double
    let max: Double
    let min: Double
}

struct SignalToNoiseRatio {
    let totalSNRdB: Double
    let bandSNR: [String: Double]
    let signalPower: Double
    let noisePower: Double
}

class QualityAnalyzer: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var ch1ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    @Published var ch2ConnectionStatus: (connected: Bool, quality: Double) = (false, 0.0)
    
    // MARK: - Private Properties
    private let SAMPLE_RATE = 250
    private let SIGNAL_BANDS: [String: (low: Double, high: Double)] = [
        "delta": (1, 4),
        "theta": (4, 8),
        "alpha": (8, 12),
        "beta": (13, 30),
        "gamma": (30, 45)
    ]
    private let NOISE_BAND = (45.0, 100.0)
    
    private var leadOffAnalysisTimer: Timer?
    private var qualityAnalysisTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Quality Analysis Methods
    func analyzeSignalQuality(channel1: [Int32], channel2: [Int32]) -> (ch1: SignalQualityMetrics?, ch2: SignalQualityMetrics?) {
        guard channel1.count >= Int(SAMPLE_RATE * 2) else { return (nil, nil) }
        
        let ch1Data = channel1.suffix(Int(SAMPLE_RATE * 5)).map { Double($0) }
        let ch2Data = channel2.suffix(Int(SAMPLE_RATE * 5)).map { Double($0) }
        
        let ch1Metrics = calculateQualityMetrics(for: ch1Data)
        let ch2Metrics = calculateQualityMetrics(for: ch2Data)
        
        return (ch1Metrics, ch2Metrics)
    }
    
    func startLeadOffAnalysis(channel1: [Int32], channel2: [Int32]) {
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performLeadOffAnalysis(ch1Data: channel1, ch2Data: channel2)
        }
    }
    
    func stopLeadOffAnalysis() {
        leadOffAnalysisTimer?.invalidate()
        leadOffAnalysisTimer = nil
    }
    
    func startQualityAnalysis(channel1: [Int32], channel2: [Int32]) {
        qualityAnalysisTimer?.invalidate()
        qualityAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let (ch1Metrics, ch2Metrics) = self?.analyzeSignalQuality(channel1: channel1, channel2: channel2) ?? (nil, nil)
            
            if let ch1 = ch1Metrics {
                print("CH1 Quality - DR: \(ch1.dynamicRange.db)dB, SNR: \(ch1.snr.totalSNRdB)dB")
            }
            if let ch2 = ch2Metrics {
                print("CH2 Quality - DR: \(ch2.dynamicRange.db)dB, SNR: \(ch2.snr.totalSNRdB)dB")
            }
        }
    }
    
    func stopQualityAnalysis() {
        qualityAnalysisTimer?.invalidate()
        qualityAnalysisTimer = nil
    }
    
    // MARK: - Private Quality Analysis Methods
    private func calculateQualityMetrics(for data: [Double]) -> SignalQualityMetrics? {
        // Calculate dynamic range
        let dr = calculateDynamicRange(data)
        
        // Calculate SNR using Welch's method
        let snr = calculateSNR(data)
        
        return SignalQualityMetrics(dynamicRange: dr, snr: snr)
    }
    
    private func calculateDynamicRange(_ data: [Double]) -> DynamicRange {
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
    
    private func calculateSNR(_ data: [Double]) -> SignalToNoiseRatio {
        guard data.count >= SAMPLE_RATE else {
            return SignalToNoiseRatio(
                totalSNRdB: 0,
                bandSNR: [:],
                signalPower: 0,
                noisePower: 0
            )
        }
        
        // Calculate power spectral density using Welch's method
        let nperseg = min(data.count / 4, SAMPLE_RATE)
        let (freqs, psd) = welch(data, fs: Double(SAMPLE_RATE), nperseg: nperseg)
        
        // Calculate power in signal bands
        var signalPower: Double = 0
        var bandSNR: [String: Double] = [:]
        
        for (bandName, (low, high)) in SIGNAL_BANDS {
            let bandPower = calculateBandPower(freqs: freqs, psd: psd, lowFreq: low, highFreq: high)
            signalPower += bandPower
            bandSNR[bandName] = bandPower
        }
        
        // Calculate noise power
        let noisePower = calculateBandPower(
            freqs: freqs,
            psd: psd,
            lowFreq: NOISE_BAND.0,
            highFreq: NOISE_BAND.1
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
    
    private func welch(_ data: [Double], fs: Double, nperseg: Int) -> (freqs: [Double], psd: [Double]) {
        let noverlap = nperseg / 2
        let step = nperseg - noverlap
        
        var psdAccumulator = [Double](repeating: 0, count: nperseg / 2 + 1)
        var segmentCount = 0
        
        // Create FFT setup once
        let log2n = vDSP_Length(log2(Double(nperseg)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
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
    
    private func computePSD(_ segment: [Double], fs: Double) -> [Double] {
        let n = segment.count
        let log2n = vDSP_Length(log2(Double(n)))
        
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return [Double](repeating: 0, count: n / 2 + 1)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
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

    private func calculateBandPower(freqs: [Double], psd: [Double], lowFreq: Double, highFreq: Double) -> Double {
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
    
    // MARK: - Lead-Off Detection (from SignalProcessing)
    private func performLeadOffAnalysis(ch1Data: [Int32], ch2Data: [Int32]) {
        let (ch1Connected, ch2Connected, ch1Quality, ch2Quality) = SignalProcessing.processLeadoffDetection(
            ch1Data: ch1Data,
            ch2Data: ch2Data
        )
        
        DispatchQueue.main.async {
            self.ch1ConnectionStatus = (ch1Connected, ch1Quality)
            self.ch2ConnectionStatus = (ch2Connected, ch2Quality)
        }
    }
    
    // MARK: - Cleanup
    func stopAllAnalysis() {
        stopLeadOffAnalysis()
        stopQualityAnalysis()
    }
    
    func resetConnectionStatus() {
        DispatchQueue.main.async {
            self.ch1ConnectionStatus = (false, 0.0)
            self.ch2ConnectionStatus = (false, 0.0)
        }
    }
}
