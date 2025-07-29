import Foundation
import Accelerate

/// Online filter matching Python's implementation for real-time EEG processing
/// Implements 0.5-40 Hz bandpass + 60 Hz notch filter
final class OnlineFilter {
    // Filter state for each channel (matching Python's sosfilt_zi)
    private var bpStateCh1: [[Double]]
    private var bpStateCh2: [[Double]]
    private var notchStateCh1: [[Double]]
    private var notchStateCh2: [[Double]]
    
    // Second-order sections for filters (matching Python scipy.signal)
    // 4th order Butterworth bandpass 0.5-40 Hz
    private let bpSOS: [[Double]] = [
        [0.003621681, 0.0072433619, 0.003621681, 1.0, -1.8151128103, 0.8310055891],
        [1.0, 2.0, 1.0, 1.0, -1.1428738642, 0.4128015981]
    ]

    // 2nd order notch filter at 60 Hz
    private let notchSOS: [[Double]] = [
        [0.9565436765, -1.8130534305, 0.9565436765, 1.0, -1.8130534305, 0.9130873534]
    ]

    private var initialized = false
    
    init() {
        // Initialize filter states for both channels
        bpStateCh1 = bpSOS.map { _ in [0.0, 0.0] }
        bpStateCh2 = bpSOS.map { _ in [0.0, 0.0] }
        notchStateCh1 = notchSOS.map { _ in [0.0, 0.0] }
        notchStateCh2 = notchSOS.map { _ in [0.0, 0.0] }
    }
    
    /// Apply filtering to new data chunk while preserving filter state
    func apply(to ch1Data: inout [Double], _ ch2Data: inout [Double]) {
        guard !ch1Data.isEmpty && !ch2Data.isEmpty else { return }
        
        // Initialize filter states with first sample if needed
        if !initialized {
            for i in 0..<bpStateCh1.count {
                bpStateCh1[i] = [ch1Data[0], ch1Data[0]]
                bpStateCh2[i] = [ch2Data[0], ch2Data[0]]
            }
            for i in 0..<notchStateCh1.count {
                notchStateCh1[i] = [ch1Data[0], ch1Data[0]]
                notchStateCh2[i] = [ch2Data[0], ch2Data[0]]
            }
            initialized = true
        }
        
        // Apply bandpass filter
        var ch1BP = ch1Data
        var ch2BP = ch2Data
        
        for (i, sos) in bpSOS.enumerated() {
            applySOS(sos: sos, data: &ch1BP, state: &bpStateCh1[i])
            applySOS(sos: sos, data: &ch2BP, state: &bpStateCh2[i])
        }
        
        // Apply notch filter
        for (i, sos) in notchSOS.enumerated() {
            applySOS(sos: sos, data: &ch1BP, state: &notchStateCh1[i])
            applySOS(sos: sos, data: &ch2BP, state: &notchStateCh2[i])
        }
        
        // Update the input arrays with filtered data
        ch1Data = ch1BP
        ch2Data = ch2BP
    }
    
    /// Apply a single second-order section filter
    private func applySOS(sos: [Double], data: inout [Double], state: inout [Double]) {
        // SOS format: [b0, b1, b2, a0, a1, a2]
        let b0 = sos[0], b1 = sos[1], b2 = sos[2]
        let a0 = sos[3], a1 = sos[4], a2 = sos[5]
        
        for i in 0..<data.count {
            let x = data[i]
            
            // Direct Form II implementation
            let v = x - a1 * state[0] - a2 * state[1]
            let y = b0 * v + b1 * state[0] + b2 * state[1]
            
            // Update state
            state[1] = state[0]
            state[0] = v
            
            data[i] = y / a0
        }
    }
}

class SignalProcessing {
    // Constants matching Python implementation
    private static let sampleRate: Double = 250.0
    private static let windowSize: Int = 250
    private static let overlapFraction: Double = 0.75
    private static let powerScale: Double = 0.84
    private static let targetBin: Int = 8
    
    // Arrays to store lead-off detection data for each channel
    private static var leadoffCh1: [Double] = []
    private static var leadoffCh2: [Double] = []
    
    // Clear stored data when starting/stopping recording
    static func resetLeadoffData() {
        leadoffCh1 = []
        leadoffCh2 = []
    }
    
    // Process lead-off detection for each channel
    static func processLeadoffDetection(ch1Data: [Int32], ch2Data: [Int32]) -> (ch1Connected: Bool, ch2Connected: Bool, ch1Quality: Double, ch2Quality: Double) {
        // Convert from Int32 to Double
        let ch1Double = ch1Data.map { Double($0) }
        let ch2Double = ch2Data.map { Double($0) }
        
        // Calculate power for each channel using Welch's method
        let ch1Power = calculateWelchPower(data: ch1Double)
        let ch2Power = calculateWelchPower(data: ch2Double)
        
        print("Lead-off Detection - Channel Powers: CH1=\(ch1Power), CH2=\(ch2Power)")
        
        // Add to lead-off arrays
        leadoffCh1.append(ch1Power)
        leadoffCh2.append(ch2Power)
        
        // Limit array size to prevent excessive memory usage
        let maxHistory = 100
        if leadoffCh1.count > maxHistory {
            leadoffCh1.removeFirst(leadoffCh1.count - maxHistory)
        }
        if leadoffCh2.count > maxHistory {
            leadoffCh2.removeFirst(leadoffCh2.count - maxHistory)
        }
        
        // Calculate connection quality
        let ch1Connected = checkConnection(data: leadoffCh1)
        let ch2Connected = checkConnection(data: leadoffCh2)
        
        // Calculate quality percentages (higher is better)
        let ch1Quality = calculateQuality(data: leadoffCh1)
        let ch2Quality = calculateQuality(data: leadoffCh2)
        
        return (ch1Connected, ch2Connected, ch1Quality, ch2Quality)
    }
    
    // Calculate power using Welch's method (matching Python implementation)
    private static func calculateWelchPower(data: [Double]) -> Double {
        guard data.count >= windowSize else {
            // Not enough data for full window
            if data.isEmpty { return 0.0 }
            var meanSquared: Double = 0.0
            vDSP_measqvD(data, 1, &meanSquared, vDSP_Length(data.count))
            return meanSquared * powerScale
        }
        
        // Use last windowSize samples
        let windowData = Array(data.suffix(windowSize))
        
        // Create FFT setup
        let log2n = vDSP_Length(log2(Double(windowSize)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return 0.0
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }
        
        // Apply window (using Hanning window as approximation to Tukey)
        var windowedData = [Double](repeating: 0.0, count: windowSize)
        var window = [Double](repeating: 0.0, count: windowSize)
        vDSP_hann_windowD(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        vDSP_vmulD(windowData, 1, window, 1, &windowedData, 1, vDSP_Length(windowSize))
        
        // Prepare for FFT
        var realPart = windowedData
        var imagPart = [Double](repeating: 0.0, count: windowSize)
        var powerSpectrum = [Double](repeating: 0.0, count: windowSize/2)
        
        // Fix the pointer issue here too
        realPart.withUnsafeMutableBufferPointer { realBuffer in
            imagPart.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPDoubleSplitComplex(
                    realp: realBuffer.baseAddress!,
                    imagp: imagBuffer.baseAddress!
                )
                
                vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmagsD(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(windowSize/2))
            }
        }
        
        // Scale power spectrum (matching Python's scaling)
        var scale = 2.0 / (Double(sampleRate) * Double(windowSize))
        vDSP_vsmulD(powerSpectrum, 1, &scale, &powerSpectrum, 1, vDSP_Length(windowSize/2))
        
        // Return power at target frequency bin
        let targetIndex = min(targetBin, powerSpectrum.count - 1)
        return powerSpectrum[targetIndex]
    }
    
    // Remove outliers using IQR method (matching Python implementation)
    private static func removeOutliers(data: [Double]) -> [Double] {
        guard data.count > 4 else { return data }
        
        let sorted = data.sorted()
        let q1Index = data.count / 4
        let q3Index = (data.count * 3) / 4
        
        guard q1Index < sorted.count && q3Index < sorted.count else { return data }
        
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1
        
        // Handle zero IQR
        if iqr == 0 {
            return data
        }
        
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        return data.filter { $0 >= lowerBound && $0 <= upperBound }
    }
    
    // Check connection based on historical data
    private static func checkConnection(data: [Double]) -> Bool {
        // Need sufficient data for reliable detection
        guard data.count > 20 else { return false }
        
        // Use first half as baseline
        let baselineCount = min(data.count / 2, 50)
        let baselineData = Array(data.prefix(baselineCount))
        
        // Compare with recent samples
        let recentData = Array(data.suffix(5))
        
        // Remove outliers from baseline
        let baselineClean = removeOutliers(data: baselineData)
        guard !baselineClean.isEmpty && !recentData.isEmpty else { return false }
        
        // Calculate statistics
        var baselineMean: Double = 0.0
        vDSP_meanvD(baselineClean, 1, &baselineMean, vDSP_Length(baselineClean.count))
        
        var recentMean: Double = 0.0
        vDSP_meanvD(recentData, 1, &recentMean, vDSP_Length(recentData.count))
        
        // Calculate baseline standard deviation
        let baselineStd = calculateStandardDeviation(data: baselineClean, mean: baselineMean)
        
        // Connection detected if recent mean is significantly higher than baseline
        let threshold = baselineMean + 2.0 * baselineStd
        return recentMean > threshold
    }
    
    // Calculate quality percentage (0-100) based on stability
    private static func calculateQuality(data: [Double]) -> Double {
        guard data.count >= 5 else { return 0.0 }
        
        // Use recent samples for quality assessment
        let recentData = Array(data.suffix(min(10, data.count)))
        let recentClean = removeOutliers(data: recentData)
        
        guard recentClean.count >= 3 else { return 0.0 }
        
        // Calculate coefficient of variation
        var mean: Double = 0.0
        vDSP_meanvD(recentClean, 1, &mean, vDSP_Length(recentClean.count))
        
        guard abs(mean) > 1e-9 else { return 50.0 }
        
        let std = calculateStandardDeviation(data: recentClean, mean: mean)
        let cv = std / abs(mean)
        
        // Map CV to quality percentage (lower CV = higher quality)
        // CV of 0 = 100% quality, CV of 1 = 0% quality
        let qualityPercentage = max(0.0, min(100.0, 100.0 * (1.0 - cv)))
        
        return qualityPercentage
    }
    
    // Calculate standard deviation
    private static func calculateStandardDeviation(data: [Double], mean: Double) -> Double {
        let count = data.count
        guard count > 1 else { return 0.0 }
        
        // Calculate variance
        var variance: Double = 0.0
        let temp = data.map { $0 - mean }
        vDSP_svesqD(temp, 1, &variance, vDSP_Length(count))
        variance = variance / Double(count - 1)
        
        return sqrt(variance)
    }
}
