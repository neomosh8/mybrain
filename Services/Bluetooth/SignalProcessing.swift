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

// MARK: - SignalProcessing (Lead-Off Detection)
class SignalProcessing {
    private static let sampleRate: Double = 250.0
    private static let windowSize: Int = 250
    private static let overlapFraction: Double = 0.75
    private static let powerScale: Double = 0.84
    private static let targetBin: Int = 8
    
    private static var leadoffCh1: [Double] = []
    private static var leadoffCh2: [Double] = []
    
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
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else { return 0 }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
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
        var scale = 2.0 / (sampleRate * Double(windowSize))
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
}
