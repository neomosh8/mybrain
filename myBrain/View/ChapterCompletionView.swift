import SwiftUI

/// A simple struct to store each feedback data point for plotting.
struct FeedbackPoint: Identifiable {
    let id = UUID()
    let index: Int      // e.g. 1, 2, 3, ...
    let label: String   // e.g. "example1"
    let value: Double   // e.g. 0.7
}

struct ChapterCompletionView: View {
    @ObservedObject var socketViewModel: WebSocketViewModel
    
    let thoughtId: Int
    
    // For the animated circle fill
    @State private var fillAmount: CGFloat = 0.0
    // For showing the checkmark
    @State private var showCheckmark = false
    
    // Loading state (for feedback request)
    @State private var isLoadingFeedback = false
    
    // Feedback data & selection
    @State private var feedbackPoints: [FeedbackPoint] = []
    @State private var selectedPoint: FeedbackPoint? = nil
    
    var body: some View {
        ZStack {
            // EInkBackground
            Color("EInkBackground")
                .ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack {
                    // 1) Growing green circle from bottom-center
                    let baseRadius = sqrt(pow(geo.size.width / 2, 2) + pow(geo.size.height, 2))
                    let maxRadius = baseRadius * 1.3
                    let currentRadius = fillAmount * maxRadius
                    
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: currentRadius * 2, height: currentRadius * 2)
                        .position(x: geo.size.width / 2, y: geo.size.height)
                        .animation(.easeInOut(duration: 2), value: fillAmount)
                    
                    // 2) Centered content: checkmark & message
                    VStack(spacing: 16) {
                        if showCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .onAppear {
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                }
                                .transition(.scale)
                            
                            // Instead of the old inline feedbackPlot:
                            if isLoadingFeedback {
                                ProgressView("Loading feedback...")
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3, anchor: .center)
                                    .padding(.top, 16)
                            } else if feedbackPoints.isEmpty {
                                Text("No feedback data")
                                    .foregroundColor(.white)
                                    .padding(.top, 16)
                            } else {
                                // Use FeedbackPlotView
                                FeedbackPlotView(
                                    feedbackPoints: feedbackPoints,
                                    selectedPoint: $selectedPoint, testMode: false
                                )
                                .frame(height: 200)
                                .padding(.horizontal)
                                .padding(.top, 16)

                                // selectedPoint info
                                if let selected = selectedPoint {
                                    selectedPointInfo(for: selected)
                                }
                            }
                        }
                        
                        Text("You have finished exploring Thought \(thoughtId)")
                            .font(.title2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    // Animation logic...
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            fillAmount = 1.0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.spring()) {
                                showCheckmark = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                requestFeedbacks()
                            }
                        }
                    }
                }
            }
        }
        .onReceive(socketViewModel.$incomingMessage) { message in
            guard let message = message else { return }
            if let type = message["type"] as? String, type == "feedbacks_response" {
                parseFeedbackResponse(message)
            }
        }
    }
    
    // Displays selected point + next 5
    private func selectedPointInfo(for point: FeedbackPoint) -> some View {
        VStack(spacing: 8) {
            Text("Selected: \(point.label) = \(point.value, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.white)
            
            if let idx = feedbackPoints.firstIndex(where: { $0.id == point.id }) {
                let nextStart = idx + 1
                let nextEnd = min(idx + 6, feedbackPoints.count)
                let nextSlice = feedbackPoints[nextStart..<nextEnd]
                if !nextSlice.isEmpty {
                    Text("Next 5 (if available): " + nextSlice.map({ $0.label }).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else {
                    Text("No further keys")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Network / Parsing
extension ChapterCompletionView {
    
    private func requestFeedbacks() {
        isLoadingFeedback = true
        let payload: [String: Any] = ["thought_id": thoughtId]
        socketViewModel.sendMessage(action: "get_feedbacks", data: payload)
    }
    
    private func parseFeedbackResponse(_ jsonObject: [String: Any]) {
        isLoadingFeedback = false
        guard let dataDict = jsonObject["data"] as? [String: Any] else { return }
        
        var tempPoints: [FeedbackPoint] = []
        let sortedKeys = dataDict.keys.sorted {
            (Int($0) ?? 0) < (Int($1) ?? 0)
        }
        
        for k in sortedKeys {
            if let itemDict = dataDict[k] as? [String: Double],
               let label = itemDict.keys.first,
               let value = itemDict.values.first,
               let index = Int(k) {
                
                let point = FeedbackPoint(index: index, label: label, value: value)
                tempPoints.append(point)
            }
        }
        
        feedbackPoints = tempPoints
    }
}
