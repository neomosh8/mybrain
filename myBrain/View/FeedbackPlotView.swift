import SwiftUI

struct FeedbackPlotView: View {
    let feedbackPoints: [FeedbackPoint]
    @Binding var selectedPoint: FeedbackPoint?
    let testMode: Bool
    
    private var syntheticPoints: [FeedbackPoint] {
        let count = 40
        return (0..<count).map { i in
            let fraction = Double(i) / Double(count - 1)
            let upwardValue = fraction * 9.0 + 1.0
            let dipStart = Int(Double(count - 1) * 0.8)
            let dipFraction = i > dipStart ? Double(i - dipStart) : 0
            let dipOffset = dipFraction * 0.5
            
            let finalValue = upwardValue - dipOffset
            return FeedbackPoint(index: i, label: "a", value: finalValue)
        }
    }
    
    private var pointsToPlot: [FeedbackPoint] {
        testMode ? syntheticPoints : feedbackPoints
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear.edgesIgnoringSafeArea(.all)
                
                Group {
                    if pointsToPlot.isEmpty {
                        EmptyView()
                    } else {
                        plotContent(in: geo)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func plotContent(in geo: GeometryProxy) -> some View {
        let xs = pointsToPlot.map { $0.index }
        let ys = pointsToPlot.map { $0.value }
        
        if let minX = xs.min(),
           let maxX = xs.max(),
           let minY = ys.min(),
           let maxY = ys.max(),
           maxX != minX,
           maxY != minY
        {
            let plotPadding: CGFloat = 10
            
            let strokePath = createStrokePath(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                size: geo.size,
                padding: plotPadding
            )
            
            let fillPath = createFillPath(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                size: geo.size,
                padding: plotPadding
            )
            
            ZStack {
                fillPath
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                strokePath
                    .stroke(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
    }
    
    private func xPosition(
        for i: Int,
        minX: Int,
        maxX: Int,
        width: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        let fraction = CGFloat(i - minX) / CGFloat(maxX - minX)
        return fraction * (width - 2 * padding) + padding
    }
    
    private func yPosition(
        for val: Double,
        minY: Double,
        maxY: Double,
        height: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        let fraction = CGFloat(val - minY) / CGFloat(maxY - minY)
        let scaled = fraction * (height - 2 * padding)
        return height - scaled - padding
    }
    
    private func createStrokePath(
        minX: Int,
        maxX: Int,
        minY: Double,
        maxY: Double,
        size: CGSize,
        padding: CGFloat
    ) -> Path {
        Path { path in
            let firstPoint = pointsToPlot[0]
            path.move(
                to: CGPoint(
                    x: xPosition(for: firstPoint.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                    y: yPosition(for: firstPoint.value, minY: minY, maxY: maxY, height: size.height, padding: padding)
                )
            )
            
            for point in pointsToPlot.dropFirst() {
                path.addLine(
                    to: CGPoint(
                        x: xPosition(for: point.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                        y: yPosition(for: point.value, minY: minY, maxY: maxY, height: size.height, padding: padding)
                    )
                )
            }
        }
    }
    
    private func createFillPath(
        minX: Int,
        maxX: Int,
        minY: Double,
        maxY: Double,
        size: CGSize,
        padding: CGFloat
    ) -> Path {
        Path { path in
            let firstPoint = pointsToPlot[0]
            path.move(
                to: CGPoint(
                    x: xPosition(for: firstPoint.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                    y: yPosition(for: firstPoint.value, minY: minY, maxY: maxY, height: size.height, padding: padding)
                )
            )
            
            for point in pointsToPlot.dropFirst() {
                path.addLine(
                    to: CGPoint(
                        x: xPosition(for: point.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                        y: yPosition(for: point.value, minY: minY, maxY: maxY, height: size.height, padding: padding)
                    )
                )
            }
            
            let lastPoint = pointsToPlot.last!
            path.addLine(
                to: CGPoint(
                    x: xPosition(for: lastPoint.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                    y: size.height - padding
                )
            )
            
            path.addLine(
                to: CGPoint(
                    x: xPosition(for: firstPoint.index, minX: minX, maxX: maxX, width: size.width, padding: padding),
                    y: size.height - padding
                )
            )
            
            path.closeSubpath()
        }
    }
}
