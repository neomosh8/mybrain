import SwiftUI

struct SpectrumView: View {
    let psd: [Double]
    var yLimit: Double = 100.0

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard psd.count > 1 else { return }
                let maxVal = yLimit
                let stepX = size.width / CGFloat(psd.count - 1)
                var path = Path()
                for i in 0..<psd.count {
                    let x = stepX * CGFloat(i)
                    let clamped = min(psd[i], maxVal)
                    let normalized = CGFloat(clamped / maxVal)
                    let y = size.height - normalized * size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(.purple), lineWidth: 2)
            }
        }
    }
}
