import Foundation

struct NotchFilter {
    private let b0: Double
    private let b1: Double
    private let b2: Double
    private let a1: Double
    private let a2: Double
    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    init(sampleRate: Double, frequency: Double, q: Double) {
        let w0 = 2.0 * Double.pi * frequency / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosw0 = cos(w0)
        let a0 = 1.0 + alpha
        b0 = 1.0 / a0
        b1 = -2.0 * cosw0 / a0
        b2 = 1.0 / a0
        a1 = -2.0 * cosw0 / a0
        a2 = (1.0 - alpha) / a0
    }

    mutating func process(sample: Double) -> Double {
        let y = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = sample
        y2 = y1
        y1 = y
        return y
    }

    mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}
