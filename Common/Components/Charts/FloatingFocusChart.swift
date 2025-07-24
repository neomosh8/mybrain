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
        MockBluetoothService.shared.feedbackPublisher
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] raw in
                guard let self = self else { return }
                // Normalize and clamp to 0–100%
                let pct = min(max(abs(raw) / 10, 0), 100)
                self.current = pct
                self.history.append(FocusData(value: raw, timestamp: .now))
                if self.history.count > 4 {
                    self.history.removeFirst()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Floating Chart View
struct FloatingFocusChart: View {
    @StateObject private var vm = FocusChartViewModel()
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 100, y: 0)
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            MiniBarChart(data: vm.history)
                .frame(width: 30, height: 25)
            Text("\(Int(vm.current))%")
                .font(.caption).bold()
            Text("Focus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.black).opacity(0.7))
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
        let screen = UIScreen.main.bounds
        let x = position.x < screen.width / 2 ? 50 : screen.width - 50
        let y = min(max(position.y, 80), screen.height - 80)
        withAnimation(.spring()) {
            position = CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Mini Bar Chart
struct MiniBarChart: View {
    let data: [FocusData]

    var body: some View {
        GeometryReader { geo in
            let count = max(data.count, 1)
            let barWidth = geo.size.width / CGFloat(count)

            ForEach(Array(data.enumerated()), id: \ .offset) { index, entry in
                let normalized = CGFloat(entry.value / 100)
                let barHeight = normalized * geo.size.height

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: barWidth * 0.6,
                           height: barHeight)
                    .position(
                        x: barWidth * (CGFloat(index) + 0.5),
                        y: geo.size.height - barHeight / 2
                    )
            }
        }
    }
}
