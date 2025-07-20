import SwiftUI
import Combine

// MARK: - Data Model
struct FocusData {
    let value: Double
    let timestamp: Date
}

// MARK: - ViewModel
class FocusChartViewModel: ObservableObject {
    @Published var history: [FocusData] = []
    @Published var current: Double = 0
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        BluetoothService.shared.feedbackPublisher
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] raw in
                guard let self = self else { return }
                // Normalize and clamp to 0–100%
                let pct = min(max(abs(raw) / 10, 0), 100)
                self.current = pct
                self.history.append(.init(value: pct, timestamp: .now))
                if self.history.count > 5 {
                    self.history.removeFirst()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Floating Chart View
struct FloatingFocusChart: View {
    @StateObject private var vm = FocusChartViewModel()
    @State private var position = CGPoint(x: 100, y: 100)
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 4) {
            MiniLineChart(data: vm.history)
                .frame(width: 40, height: 20)
            Text("\(Int(vm.current))%")
                .font(.caption).bold()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .shadow(radius: 4))
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { v in
                    if !isDragging {
                        withAnimation(.easeIn) { isDragging = true }
                    }
                    position = v.location
                }
                .onEnded { _ in
                    withAnimation(.easeOut) { isDragging = false }
                    snapToEdge()
                }
        )
    }
    
    private func snapToEdge() {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let x = position.x < w/2 ? 50 : w - 50
        let y = min(max(position.y, 80), h - 80)
        withAnimation(.spring()) {
            position = CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Mini Line Chart
struct MiniLineChart: View {
    let data: [FocusData]
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let pts = points(in: geo.size)
                guard let first = pts.first else { return }
                path.move(to: first)
                pts.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
    
    private func points(in size: CGSize) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let vals = data.map { $0.value }
        let minV = vals.min() ?? 0, maxV = vals.max() ?? 100
        let range = maxV - minV == 0 ? 1 : maxV - minV
        return data.enumerated().map { i, d in
            let x = CGFloat(i) / CGFloat(data.count - 1) * size.width
            let y = size.height * (1 - (CGFloat(d.value - minV) / CGFloat(range)))
            return CGPoint(x: x, y: y)
        }
    }
}
