import Foundation
import Accelerate

class SignalProcessing {
    // Constants
    private static let samplesPerSecond: Double = 250.0
    private static let windowSize: Int = 250
    private static let overlapFraction: Double = 0.75 // Not used in current code, but kept for context
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

        // Calculate power for each channel
        let ch1Power = calculatePower(data: ch1Double)
        let ch2Power = calculatePower(data: ch2Double)
        
        // 👇 ADD THESE DEBUG PRINTS
        print("LEADOFF DEBUG - Channel Powers:")
        print("CH1 Power: \(ch1Power)")
        print("CH2 Power: \(ch2Power)")
        // 👆 END OF ADDED CODE

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

    // Calculate power (simplified Welch method approximation)
    private static func calculatePower(data: [Double]) -> Double {
        guard !data.isEmpty else { return 0.0 }

        // If we have enough data for a window
        if data.count >= windowSize {
            // Use last windowSize samples
            let windowedData = Array(data.suffix(windowSize))

            // Apply Tukey window
            // Note: Tukey window alpha = 0.17 is quite narrow. Common values are 0.25 or 0.5.
            // Also, vDSP_vmulD multiplies element-wise, so the window needs to be the same size.
            let tukeyWindow = createTukeyWindow(size: windowSize, alpha: 0.17)
            var windowedSamples = [Double](repeating: 0.0, count: windowSize)
            // Ensure window size matches data size if using vDSP
             guard windowedData.count == tukeyWindow.count else {
                 print("Error: Window size mismatch")
                 return 0.0
             }
            vDSP_vmulD(windowedData, 1, tukeyWindow, 1, &windowedSamples, 1, vDSP_Length(windowSize))

            // Calculate FFT
            // Create FFT setup
            let log2n = vDSP_Length(log2(Double(windowSize)))
            guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
                 print("Error: Could not create FFT setup")
                 return 0.0
            }

            // Prepare input and output for in-place operation
            // Real part gets the windowed data, Imaginary part starts as zero
            // We will copy this into the output arrays for the vDSP_fft_zopD function
            var realInput = windowedSamples
            var imaginaryInput = [Double](repeating: 0.0, count: windowSize)

            // Output arrays that will hold the complex result (initially copy input for zop)
            var realOutput = realInput
            var imaginaryOutput = imaginaryInput

            // Create DSP split complex structure pointing to the output arrays
            // This structure will be used for both input and output in vDSP_fft_zopD
            var ioSplitComplex = DSPDoubleSplitComplex(realp: &realOutput, imagp: &imaginaryOutput)

            // Perform FFT in-place (using zop instead of zip)
            // vDSP_fft_zopD(setup, input, input_stride, output, output_stride, log2n, direction)
            // For in-place, input and output buffers are the same
            vDSP_fft_zopD(fftSetup, &ioSplitComplex, 1, &ioSplitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

            // Calculate power (magnitude squared) from the results in realOutput/imaginaryOutput
            // The result is in a packed format. We only need up to N/2 + 1 values.
            let halfN = windowSize / 2
            var power = [Double](repeating: 0.0, count: halfN /* +1 not needed here, see below */)

            // Use vDSP_zvmagsD to calculate magnitude squared efficiently
            // Prepare a split complex pointing to the results in realOutput/imaginaryOutput
            // No need to create a new var, just use ioSplitComplex as its pointers are correct
            vDSP_zvmagsD(&ioSplitComplex, 1, &power, 1, vDSP_Length(halfN))

            // Scale the power correctly
            // For vDSP FFT, a scaling factor is often needed.
            // Usually 1/N for power, or 1/(N*N) sometimes depending on convention.
            // Let's apply the scaling used in the original code. Check if this is correct for PSD.
            // PSD scaling often involves 1/(Fs*N) or 2/(Fs*N) for one-sided.
            // The original scaling was powerScale / Double(windowSize). Let's use that.
            // Note: vDSP_zvmagsD calculates mag^2.
            var scaledPower = [Double](repeating: 0.0, count: halfN)
            let scale = powerScale / Double(windowSize)
            vDSP_vsmulD(power, 1, [scale], &scaledPower, 1, vDSP_Length(halfN))


            // Clean up
            vDSP_destroy_fftsetupD(fftSetup)

            // Return power at target bin
            // Ensure targetBin is within the valid range [0, N/2 - 1]
            let validBin = max(0, min(targetBin, halfN - 1))
            return scaledPower[validBin]

        } else {
            // Not enough data, return simple power estimation (mean squared)
             guard !data.isEmpty else { return 0.0 } // Add check for empty data here too
             var meanSq: Double = 0.0
             vDSP_measqvD(data, 1, &meanSq, vDSP_Length(data.count))
             // Apply similar scaling? Or just return mean square? Let's keep original logic for now.
             // Original logic used mean * mean * powerScale
             var mean: Double = 0.0
             vDSP_meanvD(data, 1, &mean, vDSP_Length(data.count))
             return abs(mean * mean * powerScale) // Return abs just in case
        }
    }

    // Create a Tukey window
    private static func createTukeyWindow(size: Int, alpha: Double) -> [Double] {
        var window = [Double](repeating: 0.0, count: size)
        guard size > 1 else { return window } // Handle edge case

        let n = Double(size)
        let m = Double(size - 1)
        let alphaN = alpha * n / 2.0 // Number of samples in taper

        for i in 0..<size {
            let x = Double(i)
            if x < alphaN { // Rising edge
                window[i] = 0.5 * (1.0 - cos(.pi * x / alphaN))
            } else if x >= (n - alphaN) { // Falling edge
                window[i] = 0.5 * (1.0 - cos(.pi * (n - 1.0 - x) / alphaN))
            } else { // Plateau
                window[i] = 1.0
            }
        }
        // Alternative definition check (some use i/(N-1)) - the one above seems more common for vDSP indexing
        /*
        for i in 0..<size {
            let i_double = Double(i)
            if i_double < alpha * m / 2.0 {
                window[i] = 0.5 * (1.0 + cos(.pi * (2.0 * i_double / (alpha * m) - 1.0))) // Corrected formula
            } else if i_double >= m * (1.0 - alpha / 2.0) {
                 window[i] = 0.5 * (1.0 + cos(.pi * (2.0 * i_double / (alpha * m) - 2.0 / alpha + 1.0))) // Corrected formula
            } else {
                window[i] = 1.0
            }
        }
        */

        return window
    }

    // Remove outliers using IQR method
    private static func removeOutliers(data: [Double]) -> [Double] {
        guard data.count > 4 else { return data }

        let sorted = data.sorted()
        // Use integer division which rounds down, safer for indexing
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4

        // Ensure indices are valid (especially for small counts slightly > 4)
        guard q3Index < sorted.count, q1Index < q3Index else { return data }

        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        // Handle IQR == 0 case to avoid infinite bounds
        if iqr == 0 {
            // If IQR is zero, perhaps filter based on mean +/- std dev, or just return original data if all values are same
             if q1 == q3 { return data.filter { $0 == q1 } } // Keep only the identical values
             else { return data } // Fallback if something is weird
        }

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        return data.filter { $0 >= lowerBound && $0 <= upperBound }
    }

    // Check connection based on historical data
    private static func checkConnection(data: [Double]) -> Bool {
        // Require more data for a reliable check
        guard data.count > 20 else { return false } // Increased minimum count

        // Use a more stable baseline, e.g., first half, exclude most recent points
        let baselineCount = data.count / 2
        let recentCount = data.count - baselineCount
        guard baselineCount >= 10, recentCount >= 5 else { return false } // Ensure enough points in each segment

        let baselineData = Array(data.prefix(baselineCount))
        // Compare baseline to the *last* few points, excluding the very latest one perhaps
        let newData = Array(data.suffix(5)) // Look at the trend in the last 5 points

        // Remove outliers from baseline only? Or both? Let's try baseline only for stability.
        let baselineClean = removeOutliers(data: baselineData)
        // let newDataClean = removeOutliers(data: newData) // Optional: clean recent data too

        guard !baselineClean.isEmpty, !newData.isEmpty else { return false }

        // Calculate means
        var baselineMean: Double = 0.0
        vDSP_meanvD(baselineClean, 1, &baselineMean, vDSP_Length(baselineClean.count))
        var newDataMean: Double = 0.0
        vDSP_meanvD(newData, 1, &newDataMean, vDSP_Length(newData.count))


        // Simplified check: Is the recent mean significantly higher than the baseline?
        // Use standard deviation for thresholding
        let baselineStd = calculateStandardDeviation(data: baselineClean, mean: baselineMean)

        // Threshold: Is the new mean greater than baseline + X * std_dev?
        // Let's use a threshold factor, e.g., 1.0 or 1.5
        let thresholdFactor = 1.5
        let threshold = baselineMean + thresholdFactor * baselineStd



        return newDataMean > threshold 

        /* // Original statistical comparison (can be complex to tune)
        let baselineStd = calculateStandardDeviation(data: baselineClean, mean: baselineMean)
        let newDataStd = calculateStandardDeviation(data: newData, mean: newDataMean)

        let n1 = Double(baselineClean.count)
        let n2 = Double(newData.count)

        // Pooled standard deviation (approximation, assumes equal variance - might not hold)
        // let pooledVariance = ((n1 - 1) * baselineStd * baselineStd + (n2 - 1) * newDataStd * newDataStd) / (n1 + n2 - 2)
        // let standardError = sqrt(pooledVariance * (1/n1 + 1/n2))

        // Standard error for unequal variances (Welch's t-test approach)
        let term1 = baselineStd * baselineStd / n1
        let term2 = newDataStd * newDataStd / n2
        guard (term1 + term2) > 0 else { return false } // Avoid division by zero
        let standardError = sqrt(term1 + term2)


        let tStat = (newDataMean - baselineMean) / standardError

        // Use a fixed t-statistic threshold (e.g., corresponding to p < 0.05 or p < 0.1 for a one-tailed test)
        // For reasonable degrees of freedom (e.g., > 10), t ~ 1.7 (p<0.05 one-tail) or t ~ 1.3 (p<0.1 one-tail)
        let tThreshold: Double = 1.3 // Corresponds roughly to p < 0.1 one-tailed

        return tStat > tThreshold // Check if new mean is significantly GREATER
        */
    }


    // Calculate quality percentage (0-100) based on stability
    private static func calculateQuality(data: [Double]) -> Double {
        guard data.count >= 5 else { return 0.0 } // Use at least 5 points for stability calc

        // Use the last 5-10 points for recent stability
        let recentData = Array(data.suffix(min(10, data.count)))
        guard recentData.count >= 5 else { return 0.0 } // Ensure we still have enough points

        // Remove outliers from this recent subset as well
        let recentClean = removeOutliers(data: recentData)
        guard recentClean.count >= 3 else { return 0.0 } // Need at least 3 points after cleaning

        // Calculate coefficient of variation (CV = std_dev / mean)
        var mean: Double = 0.0
        vDSP_meanvD(recentClean, 1, &mean, vDSP_Length(recentClean.count))

        guard abs(mean) > 1e-9 else { return 50.0 } // Avoid division by zero or near-zero mean; assign neutral quality?

        let std = calculateStandardDeviation(data: recentClean, mean: mean)
        let cv = std / abs(mean)

        // Map CV to quality (0-100). Lower CV is better.
        // CV = 0 -> Quality 100
        // CV = 0.1 -> Quality 90?
        // CV = 0.5 -> Quality 50?
        // CV >= 1.0 -> Quality 0
        // Let's use a simple linear mapping: Quality = 100 * (1 - CV), capped at [0, 100]
        let qualityPercentage = max(0.0, min(100.0, 100.0 * (1.0 - cv)))

        return qualityPercentage
    }

    // Calculate standard deviation
    private static func calculateStandardDeviation(data: [Double], mean: Double) -> Double {
        let count = data.count
        guard count > 1 else { return 0.0 }

        // Calculate sum of squared differences from the mean
        var meanArray = [Double](repeating: mean, count: count)
        var diff = [Double](repeating: 0.0, count: count)
        vDSP_vsubD(meanArray, 1, data, 1, &diff, 1, vDSP_Length(count)) // diff = mean - data

        var sumSq: Double = 0.0
        vDSP_dotprD(diff, 1, diff, 1, &sumSq, vDSP_Length(count)) // sumSq = sum(diff^2)

        // Variance = sumSq / (n-1) for sample standard deviation
        let variance = sumSq / Double(count - 1)

        return sqrt(variance)
    }
}

extension SignalProcessing {
    static func welchPowerSpectrum(data: [Int32], sampleRate: Double, maxFrequency: Double = 100.0) -> [Double] {
        let doubleData = data.map { Double($0) }
        let windowSize = 256
        let overlap = 0.5
        guard doubleData.count >= windowSize else { return [] }
        let step = Int(Double(windowSize) * (1.0 - overlap))
        let log2n = vDSP_Length(log2(Double(windowSize)))
        let window = vDSP.window(ofType: Double.self,
                                 usingSequence: .hanningDenormalized,
                                 count: windowSize,
                                 isHalfWindow: false)
        var accumulated = [Double](repeating: 0.0, count: windowSize / 2)
        var segmentCount = 0
        var real = [Double](repeating: 0.0, count: windowSize)
        var imag = [Double](repeating: 0.0, count: windowSize)
        for start in stride(from: 0, through: doubleData.count - windowSize, by: step) {
            let segment = Array(doubleData[start..<start+windowSize])
            vDSP_vmulD(segment, 1, window, 1, &real, 1, vDSP_Length(windowSize))
            imag = [Double](repeating: 0.0, count: windowSize)
            var split = DSPDoubleSplitComplex(realp: &real, imagp: &imag)
            guard let setup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else { continue }
            vDSP_fft_zripD(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            var mags = [Double](repeating: 0.0, count: windowSize/2)
            vDSP_zvmagsD(&split, 1, &mags, 1, vDSP_Length(windowSize/2))
            vDSP_destroy_fftsetupD(setup)
            vDSP_vaddD(mags, 1, accumulated, 1, &accumulated, 1, vDSP_Length(windowSize/2))
            segmentCount += 1
        }
        guard segmentCount > 0 else { return [] }
        var scale = 1.0 / Double(segmentCount)
        vDSP_vsmulD(accumulated, 1, &scale, &accumulated, 1, vDSP_Length(accumulated.count))
        let freqResolution = sampleRate / Double(windowSize)
        let maxIndex = min(accumulated.count - 1, Int(maxFrequency / freqResolution))
        return Array(accumulated[0...maxIndex])
    }
}

extension SignalProcessing {
    static func thetaBetaRatio(psd: [Double], sampleRate: Double) -> Double {
        guard !psd.isEmpty else { return 0.0 }
        let windowSize = 256.0
        let binWidth = sampleRate / windowSize
        func power(in range: ClosedRange<Double>) -> Double {
            let start = Int(range.lowerBound / binWidth)
            let end = Int(range.upperBound / binWidth)
            let clampedStart = max(0, start)
            let clampedEnd = min(psd.count - 1, end)
            guard clampedEnd >= clampedStart else { return 0.0 }
            return psd[clampedStart...clampedEnd].reduce(0, +)
        }
        let thetaPower = power(in: 4.0...8.0)
        let betaPower = power(in: 13.0...30.0)
        return betaPower != 0 ? thetaPower / betaPower : 0.0
    }

    /// Compute a simple moving average with the provided window size.
    /// - Parameters:
    ///   - values: Array of values to smooth.
    ///   - windowSize: Number of points to average over.
    /// - Returns: The smoothed array.
    static func movingAverage(values: [Double], windowSize: Int) -> [Double] {
        guard windowSize > 1, !values.isEmpty else { return values }
        var result: [Double] = []
        var sum: Double = 0
        for (index, value) in values.enumerated() {
            sum += value
            if index >= windowSize {
                sum -= values[index - windowSize]
            }
            let count = min(windowSize, index + 1)
            result.append(sum / Double(count))
        }
        return result
    }
}
