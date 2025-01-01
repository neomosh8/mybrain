import SwiftUI

/// A simple struct to store each feedback data point for plotting.
struct FeedbackPoint: Identifiable {
    let id = UUID()
    let index: Int      // e.g. 1, 2, 3, ...
    let label: String   // e.g. "example1"
    let value: Double   // e.g. 0.7
}

/// The new ChapterCompletionView
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
            // Keep the E-ink background behind everything
            Color("EInkBackground")
                .ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack {
                    // 1) Growing green circle from the bottom-center
                    let baseRadius = sqrt(pow(geo.size.width / 2, 2) + pow(geo.size.height, 2))
                    // Multiply by ~1.3 so it fully covers wide/tall screens
                    let maxRadius = baseRadius * 1.3
                    let currentRadius = fillAmount * maxRadius
                    
                    Circle()
                        .fill(Color.green.opacity(0.6))
                        // Make the circle’s diameter = 2 * currentRadius
                        .frame(width: currentRadius * 2, height: currentRadius * 2)
                        // Position the center of the circle at the bottom-center of the screen
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
                                    // Haptic feedback
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                }
                                .transition(.scale)
                            
                            // ---- Show either loading spinner OR the plot ----
                            if isLoadingFeedback {
                                // Just requested feedback => show loading spinner
                                ProgressView("Loading feedback...")
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.3, anchor: .center)
                                    .padding(.top, 16)
                            } else if feedbackPoints.isEmpty {
                                // Not loading, but no data => could show "No data" or remain blank
                                // Here, let's just show a placeholder
                                Text("No feedback data")
                                    .foregroundColor(.white)
                                    .padding(.top, 16)
                            } else {
                                // Feedback data ready => show plot
                                feedbackPlot
                                    .frame(height: 200)
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                
                                // Info about selected point + next 5
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
                    // 1) After 0.5s, start the 2-second circle animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            fillAmount = 1.0
                        }
                        // 2) Wait 2s for the circle animation to finish
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Circle done => animate checkmark
                            withAnimation(.spring()) {
                                showCheckmark = true
                            }
                            // 3) Give the checkmark a moment to appear before requesting feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                requestFeedbacks()
                            }
                        }
                    }
                }
            }
        }
        // Listen for *any* incoming WebSocket message
        .onReceive(socketViewModel.$incomingMessage) { message in
            guard let message = message else { return }
            // Check if it's a feedbacks_response
            if let type = message["type"] as? String, type == "feedbacks_response" {
                parseFeedbackResponse(message)
            }
        }
    }
    
    /// A simple line-plot of the feedback data
    private var feedbackPlot: some View {
        GeometryReader { geo in
            ZStack {
                // Light grid background
                Color.white.opacity(0.2)
                    .cornerRadius(8)
                
                // The line itself
                if !feedbackPoints.isEmpty {
                    Path { path in
                        let xs = feedbackPoints.map { $0.index }
                        let ys = feedbackPoints.map { $0.value }
                        
                        guard let minX = xs.min(),
                              let maxX = xs.max(),
                              let minY = ys.min(),
                              let maxY = ys.max(),
                              maxX != minX,
                              maxY != minY else {
                            return
                        }
                        
                        let plotPadding: CGFloat = 10
                        
                        func xPosition(for i: Int) -> CGFloat {
                            let fraction = CGFloat(i - minX) / CGFloat(maxX - minX)
                            return fraction * (geo.size.width - 2 * plotPadding) + plotPadding
                        }
                        
                        func yPosition(for val: Double) -> CGFloat {
                            // 0 at top in SwiftUI
                            let fraction = CGFloat(val - minY) / CGFloat(maxY - minY)
                            let scaled = fraction * (geo.size.height - 2 * plotPadding)
                            return geo.size.height - scaled - plotPadding
                        }
                        
                        // Move to first point
                        let firstPoint = feedbackPoints[0]
                        path.move(
                            to: CGPoint(
                                x: xPosition(for: firstPoint.index),
                                y: yPosition(for: firstPoint.value)
                            )
                        )
                        
                        // Connect subsequent points
                        for point in feedbackPoints.dropFirst() {
                            path.addLine(
                                to: CGPoint(
                                    x: xPosition(for: point.index),
                                    y: yPosition(for: point.value)
                                )
                            )
                        }
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    
                    // Draw circles for each data point
                    ForEach(feedbackPoints) { point in
                        let allXs = feedbackPoints.map { $0.index }
                        let minX = allXs.min() ?? 0
                        let maxX = allXs.max() ?? 1
                        
                        let allYs = feedbackPoints.map { $0.value }
                        let minY = allYs.min() ?? 0.0
                        let maxY = allYs.max() ?? 1.0
                        
                        let fractionX = maxX != minX
                            ? CGFloat(point.index - minX) / CGFloat(maxX - minX)
                            : 0.0
                        let fractionY = maxY != minY
                            ? CGFloat((point.value - minY) / (maxY - minY))
                            : 0.0
                        
                        let plotPadding: CGFloat = 10
                        
                        let circleX = fractionX * (geo.size.width - 2*plotPadding) + plotPadding
                        let circleY = geo.size.height
                            - fractionY * (geo.size.height - 2*plotPadding)
                            - plotPadding
                        
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                            .position(x: circleX, y: circleY)
                            .onTapGesture {
                                // Select this data point
                                selectedPoint = point
                            }
                    }
                }
            }
        }
    }
    
    /// Shows the selected point’s label + the next 5 labels in the feedback array
    private func selectedPointInfo(for point: FeedbackPoint) -> some View {
        VStack(spacing: 8) {
            Text("Selected: \(point.label) = \(point.value, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.white)
            
            // Gather the next 5 labels
            if let idx = feedbackPoints.firstIndex(where: { $0.id == point.id }) {
                let nextStart = idx + 1
                let nextEnd = min(idx + 6, feedbackPoints.count) // 5 points after
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
    
    /// After the checkmark shows (plus a short delay), request the feedback data from server
    private func requestFeedbacks() {
        // Indicate that we are now loading
        isLoadingFeedback = true
        
        let payload: [String: Any] = [
            "thought_id": thoughtId
        ]
        socketViewModel.sendMessage(action: "get_feedbacks", data: payload)
    }
    
    /// Parse the feedbacks_response payload. Sample:
    /// {
    ///   "type": "feedbacks_response",
    ///   "status": "success",
    ///   "message": "Feedback entries retrieved successfully",
    ///   "data": {
    ///       "1": { "example1": 0.7 },
    ///       "2": { "example2": 0.8 },
    ///       "3": { "example3": 0.9 }
    ///   }
    /// }
    private func parseFeedbackResponse(_ jsonObject: [String: Any]) {
        // We got a response => no longer loading
        isLoadingFeedback = false
        
        guard let dataDict = jsonObject["data"] as? [String: Any] else { return }
        
        var tempPoints: [FeedbackPoint] = []
        
        // Sort keys numerically: "1", "2", "3", ...
        let sortedKeys = dataDict.keys.sorted { k1, k2 in
            (Int(k1) ?? 0) < (Int(k2) ?? 0)
        }
        
        for k in sortedKeys {
            // Each item is like { "example1": 0.7 }
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
