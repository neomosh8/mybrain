import SwiftUI

struct TBRPlotView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard values.count > 1 else { return }

                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = max(maxVal - minVal, 0.0001)
                let stepX = size.width / CGFloat(values.count - 1)

                var path = Path()
                for i in 0..<values.count {
                    let x = CGFloat(i) * stepX
                    let normalized = (values[i] - minVal) / range
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
