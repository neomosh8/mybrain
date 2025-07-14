import SwiftUI

struct TBRPlotView: View {
    let values: [Double]
    let color: Color

    private let smoothWindow = 5

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let smoothed = SignalProcessing.movingAverage(values: values, windowSize: smoothWindow)
                guard smoothed.count > 1 else { return }

                let minVal = smoothed.min() ?? 0
                let maxVal = smoothed.max() ?? 1
                let range = max(maxVal - minVal, 0.0001)
                let stepX = size.width / CGFloat(smoothed.count - 1)

                var path = Path()
                for i in 0..<smoothed.count {
                    let x = CGFloat(i) * stepX
                    let normalized = (smoothed[i] - minVal) / range
                    let y = size.height - CGFloat(normalized) * size.height
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(color), lineWidth: 2)
            }
        }
    }
}
