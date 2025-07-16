import Combine
import SwiftUI

// MARK: - Focus Data Model
struct FocusData {
    let value: Double
    let timestamp: Date
}

// MARK: - Focus Chart View Model
class FocusChartViewModel: ObservableObject {
    @Published var focusHistory: [FocusData] = []
    @Published var currentFocus: Double = 0.0

    private var cancellables = Set<AnyCancellable>()
    private let bluetoothService = BluetoothService.shared

    init() {
        setupFocusDataSubscription()
    }

    private func setupFocusDataSubscription() {
        // Subscribe to Bluetooth feedback values
        bluetoothService.$feedbackValue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.updateFocusData(value)
            }
            .store(in: &cancellables)
    }

    private func updateFocusData(_ value: Double) {
        // Convert raw EEG value to focus percentage (0-100)
        let focusPercentage = convertToFocusPercentage(value)
        currentFocus = focusPercentage

        // Add to history
        let focusData = FocusData(value: focusPercentage, timestamp: Date())
        focusHistory.append(focusData)

        // Keep only last 5 values
        if focusHistory.count > 5 {
            focusHistory.removeFirst()
        }
    }

    private func convertToFocusPercentage(_ rawValue: Double) -> Double {
        // Convert raw EEG value to 0-100 percentage
        // This is a simplified conversion - adjust based on your EEG data range
        let normalized = abs(rawValue) / 1000.0  // Adjust divisor based on your data range
        return min(max(normalized * 100, 0), 100)
    }

    var averageFocus: Double {
        guard !focusHistory.isEmpty else { return 0.0 }
        return focusHistory.map { $0.value }.reduce(0, +)
            / Double(focusHistory.count)
    }
}

// MARK: - Floating Focus Chart
struct FloatingFocusChart: View {
    @StateObject private var viewModel = FocusChartViewModel()
    @State private var position = CGPoint(x: 100, y: 100)
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            MiniLineChart(data: viewModel.focusHistory)
                .frame(width: 40, height: 20)
            
            Text("\(Int(viewModel.currentFocus))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(.black))
            
            Text("Focus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.black).opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.white))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    position = value.location
                }
                .onEnded { _ in
                    isDragging = false
                    snapToEdge()
                }
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.6),
            value: isDragging
        )
    }

    private func snapToEdge() {
        // Get screen bounds
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        // Chart dimensions
        let chartWidth: CGFloat = 84
        let chartHeight: CGFloat = 60

        // Calculate safe boundaries
        let minX = chartWidth / 2 + 20
        let maxX = screenWidth - chartWidth / 2 - 20
        let minY = chartHeight / 2 + 100  // Account for navigation bar
        let maxY = screenHeight - chartHeight / 2 - 150  // Account for bottom bar

        // Snap to nearest edge
        let newX: CGFloat
        if position.x < screenWidth / 2 {
            newX = minX
        } else {
            newX = maxX
        }

        let newY = min(max(position.y, minY), maxY)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            position = CGPoint(x: newX, y: newY)
        }
    }
}

// MARK: - Mini Line Chart
struct MiniLineChart: View {
    let data: [FocusData]

    var body: some View {
        GeometryReader { geometry in
            if data.count >= 2 {
                Path { path in
                    let points = calculatePoints(in: geometry.size)

                    guard let firstPoint = points.first else { return }
                    path.move(to: firstPoint)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                // Data points
                ForEach(
                    Array(calculatePoints(in: geometry.size).enumerated()),
                    id: \.offset
                ) { index, point in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 3, height: 3)
                        .position(point)
                }
            } else {
                // Placeholder when not enough data
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }
        }
    }

    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard data.count >= 2 else { return [] }

        let maxValue = data.map { $0.value }.max() ?? 100
        let minValue = data.map { $0.value }.min() ?? 0
        let range = maxValue - minValue

        return data.enumerated().map { index, focusData in
            let x = CGFloat(index) / CGFloat(data.count - 1) * size.width
            let normalizedValue =
                range > 0 ? (focusData.value - minValue) / range : 0.5
            let y = size.height - (CGFloat(normalizedValue) * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}
