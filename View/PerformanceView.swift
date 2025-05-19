import SwiftUI
import Combine

// MARK: - PerformanceView
struct PerformanceView: View {
    @ObservedObject var viewModel: PerformanceViewModel
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            ScrollView {
                VStack {
                    
                    HStack {
                        Text("Your Current Attention Capacity level: ")
                            .font(.headline) +
                        Text("\(viewModel.batteryLevel ?? -1)%")
                            .font(.headline)
                            .foregroundColor(
                                viewModel.batteryLevel ?? 0 > 70 ? .green :
                                viewModel.batteryLevel ?? 0 >= 40 ? .yellow : .red
                            )
                    }
                    .padding(.bottom, 8)
                    .padding(.top, 45)

                    // Description after current battery level + separator
                    Text("This is your current level of attention capacity, comparing to your best")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .frame(width: 280)  // Adjust this width to match the width of the text above
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    Divider()
                        .padding(.bottom, 50)
                    
                    Text("Brain Dashboard")
                        .font(.largeTitle)
                        .padding(.bottom, 2)

                    Text("Below is a representation your attention capacity for the first minute of typical listening.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .frame(width: 280)  // Adjust width as needed
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 42)
                    
                    
                    Text("Your Average Attention Capacity Per Minutes")
                        .font(.subheadline)
                        .padding(.bottom, 8)
                    

                    
                    // The animated chart
                    AnimatedLineChartView()
                        .frame(height: 300)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    // Legend
                    HStack(spacing: 20) {
                        HStack {
                            Circle().fill(Color.gray).frame(width: 10, height: 10)
                            Text("Your Usual Attention")
                        }
                        HStack {
                            Circle().fill(Color.blue).frame(width: 10, height: 10)
                            Text("Your Utilized Attention")
                        }
                    }
                    .font(.caption)
                    .padding(.bottom, 16)
                    
                    // TrendView and HistoryView
                    VStack(spacing: 16) {
                        TrendView()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                        
                        HistoryView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .shadow(radius: 1)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical)
            }
        }
        .onAppear(perform: loadData)
    }
    
    func loadData() {
        viewModel.fetchBatteryLevel()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch battery level: \(error)")
                }
            }, receiveValue: { level in
                viewModel.batteryLevel = level
            })
            .store(in: &viewModel.cancellables)
    }
}

// MARK: - AnimatedLineChartView
struct AnimatedLineChartView: View {
    @State private var animationProgressGray: CGFloat = 0
    @State private var animationProgressBlue: CGFloat = 0
    
    private let grayData: [CGFloat] = {
        let a_blue: CGFloat = 10
        let b_blue: CGFloat = 0.1
        let x0: CGFloat = 20
        let slope: CGFloat = 0.02
        let y0 = a_blue - slope * x0
        
        return (0...50).map { i in
            let x = CGFloat(i)
            if x < x0 {
                let noise = CGFloat.random(in: -0.1...0.1)
                return a_blue - slope * x + noise
            } else {
                let noise = CGFloat.random(in: -0.1...0.1)
                return y0 * pow(CGFloat(M_E), -b_blue * (x - x0)) + noise
            }
        }
    }()
    
    private let blueData: [CGFloat] = {
        let a_blue: CGFloat = 10
        let b_blue: CGFloat = 0.04
        let x0: CGFloat = 35
        let slope: CGFloat = 0.02
        let y0 = a_blue - slope * x0
        
        return (0...50).map { i in
            let x = CGFloat(i)
            if x < x0 {
                let noise = CGFloat.random(in: -0.1...0.1)
                return a_blue - slope * x + noise
            } else {
                let noise = CGFloat.random(in: -0.6...0.6)
                return y0 * pow(CGFloat(M_E), -b_blue * (x - x0)) + noise
            }
        }
    }()
    
    var body: some View {
        GeometryReader { proxy in
            let chartWidth  = proxy.size.width
            let chartHeight = proxy.size.height
            
            let globalMax = max(
                grayData.max() ?? 1,
                blueData.max() ?? 1
            )
            let globalMin = min(
                grayData.min() ?? 0,
                blueData.min() ?? 0
            )
            
            ZStack {
                // Gray Fill + Line
                FillBetweenShape(data: grayData, minY: globalMin, maxY: globalMax)
                    .trim(from: 0, to: animationProgressGray)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                LineShape(data: grayData, minY: globalMin, maxY: globalMax)
                    .trim(from: 0, to: animationProgressGray)
                    .stroke(
                        Color.gray,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                
                // Blue Fill + Line
                FillBetweenShape(data: blueData, minY: globalMin, maxY: globalMax)
                    .trim(from: 0, to: animationProgressBlue)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.blue.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                LineShape(data: blueData, minY: globalMin, maxY: globalMax)
                    .trim(from: 0, to: animationProgressBlue)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                
                // Horizontal axis + Ticks
                XAxisView(
                    dataCount: grayData.count,
                    chartWidth: chartWidth,
                    chartHeight: chartHeight
                )
                
                // "SECONDS" Label (bottom center)
                VStack {
                    Spacer()
                    Text("Seconds")
                        .font(.footnote)
                        .padding(.top, 2)
                }
                .frame(height: chartHeight)
            }
            .frame(width: chartWidth, height: chartHeight)
            .onAppear {
                // Reset first
                animationProgressGray = 0
                animationProgressBlue = 0
                
                // 1) Animate the gray line
                withAnimation(.easeInOut(duration: 2.0)) {
                    animationProgressGray = 1.0
                }
                
                // 2) Once gray is done, animate the blue line
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        animationProgressBlue = 1.0
                    }
                }
            }
        }
    }
}

// MARK: - Shapes
struct LineShape: Shape {
    let data: [CGFloat]
    let minY: CGFloat
    let maxY: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        func yPos(for value: CGFloat) -> CGFloat {
            let ratio = (value - minY) / (maxY - minY)
            return rect.height - (ratio * rect.height)
        }
        
        let xStep = rect.width / CGFloat(data.count - 1)
        path.move(to: CGPoint(x: 0, y: yPos(for: data[0])))
        
        for i in 1..<data.count {
            let x = CGFloat(i) * xStep
            path.addLine(to: CGPoint(x: x, y: yPos(for: data[i])))
        }
        return path
    }
}

struct FillBetweenShape: Shape {
    let data: [CGFloat]
    let minY: CGFloat
    let maxY: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard data.count > 1 else { return path }
        
        func yPos(for value: CGFloat) -> CGFloat {
            let ratio = (value - minY) / (maxY - minY)
            return rect.height - (ratio * rect.height)
        }
        
        let xStep = rect.width / CGFloat(data.count - 1)
        path.move(to: CGPoint(x: 0, y: yPos(for: data[0])))
        
        for i in 1..<data.count {
            let x = CGFloat(i) * xStep
            path.addLine(to: CGPoint(x: x, y: yPos(for: data[i])))
        }
        
        // Close the shape to the bottom
        path.addLine(to: CGPoint(x: xStep * CGFloat(data.count - 1),
                                 y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - XAxisView
struct XAxisView: View {
    let dataCount: Int
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    
    var body: some View {
        ZStack {
            // The horizontal axis line
            Path { path in
                path.move(to: CGPoint(x: 0, y: chartHeight))
                path.addLine(to: CGPoint(x: chartWidth, y: chartHeight))
            }
            .stroke(Color.gray, lineWidth: 1)
            
            // Ticks every 5 data points, for example
            let xStep = chartWidth / CGFloat(dataCount - 1)
            ForEach(0..<dataCount, id: \.self) { i in
                if i % 5 == 0 {
                    Path { tick in
                        let x = CGFloat(i) * xStep
                        tick.move(to: CGPoint(x: x, y: chartHeight))
                        tick.addLine(to: CGPoint(x: x, y: chartHeight - 5))
                    }
                    .stroke(Color.gray, lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - PerformanceView Preview
struct PerformanceView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide an instance of PerformanceViewModel here,
        // possibly with test or mock data for preview purposes
        PerformanceView(viewModel: PerformanceViewModel())
    }
}
