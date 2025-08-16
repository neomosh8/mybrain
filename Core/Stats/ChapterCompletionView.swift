import SwiftUI
import Combine

struct FeedbackPoint: Identifiable {
    let id = UUID()
    let index: Int
    let label: String
    let value: Double
}

struct ChapterCompletionView: View {
    let thoughtId: String
    let thoughtName: String
    let onDismiss: () -> Void
    
    @State private var fillAmount: CGFloat = 0.0
    @State private var showCheckmark = false
    @State private var isLoadingFeedback = false
    @State private var feedbackPoints: [FeedbackPoint] = []
    @State private var selectedPoint: FeedbackPoint? = nil
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showChart = false
    
    var body: some View {
        NavigationView {
            ZStack {
                mainContent
            }
        }
        .navigationBarHidden(true)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
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
        .onReceive(networkService.webSocket.messages) { message in
            switch message {
            case .feedbackResponse(let status, _, let data):
                if status.isSuccess {
                    parseFeedbackResponse(data ?? [:])
                }
            default:
                break
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Close") {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        onDismiss()
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Thought Complete")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 50)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .background(Color.green.opacity(0.3))
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .trim(from: 0, to: fillAmount)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 2.0), value: fillAmount)
                            
                            if showCheckmark {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.green)
                                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                                    .opacity(showCheckmark ? 1.0 : 0.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCheckmark)
                            }
                        }
                        
                        Text("You have finished exploring Thought \"\(thoughtName)\"")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 16) {
                        Text("Your Focus Journey")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack {
                            if isLoadingFeedback {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                        .scaleEffect(1.2)
                                    
                                    Text("Loading your focus data...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green)
                                }
                                .frame(height: 200)
                            } else if !feedbackPoints.isEmpty && showChart {
                                VStack {
                                    FeedbackPlotView(
                                        feedbackPoints: feedbackPoints,
                                        selectedPoint: $selectedPoint,
                                        testMode: false
                                    )
                                    .frame(height: 200)
                                    .opacity(showChart ? 1.0 : 0.0)
                                    .scaleEffect(showChart ? 1.0 : 0.8)
                                    .animation(.easeInOut(duration: 0.6), value: showChart)
                                    
                                    if let selected = selectedPoint {
                                        selectedPointInfo(for: selected)
                                            .opacity(showChart ? 1.0 : 0.0)
                                            .animation(.easeInOut(duration: 0.6).delay(0.3), value: showChart)
                                    }
                                }
                            } else if !feedbackPoints.isEmpty {
                                VStack {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 200)
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green.opacity(0.6))
                                    
                                    Text("No focus data available")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.green.opacity(0.8))
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
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
                    Text(
                        "Next 5 (if available): " + nextSlice
                            .map({ $0.label })
                            .joined(separator: ", ")
                    )
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

    private func requestFeedbacks() {
        isLoadingFeedback = true
        networkService.thoughts.getThoughtFeedbacks(thoughtId: thoughtId)
            .sink { result in
                self.isLoadingFeedback = false
                switch result {
                case .success(let response):
                    self.parseFeedbackFromHTTP(response)
            
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation {
                            self.showChart = true
                        }
                    }
                case .failure(let error):
                    print("Failed to get feedbacks: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func parseFeedbackFromHTTP(_ response: ThoughtFeedbacksResponse) {
        var tempPoints: [FeedbackPoint] = []
        let sortedKeys = response.feedbacks.keys.sorted {
            (Int($0) ?? 0) < (Int($1) ?? 0)
        }
        
        for k in sortedKeys {
            if let anyCodable = response.feedbacks[k],
               let itemDict = anyCodable.value as? [String: Double],
               let label = itemDict.keys.first,
               let value = itemDict.values.first,
               let index = Int(k) {
                
                let point = FeedbackPoint(
                    index: index,
                    label: label,
                    value: value
                )
                tempPoints.append(point)
            }
        }
        
        feedbackPoints = tempPoints
    }
    
    private func parseFeedbackResponse(_ jsonObject: [String: Any]) {
        isLoadingFeedback = false
        guard let dataDict = jsonObject["data"] as? [String: Any] else {
            return
        }
        
        var tempPoints: [FeedbackPoint] = []
        let sortedKeys = dataDict.keys.sorted {
            (Int($0) ?? 0) < (Int($1) ?? 0)
        }
        
        for k in sortedKeys {
            if let itemDict = dataDict[k] as? [String: Double],
               let label = itemDict.keys.first,
               let value = itemDict.values.first,
               let index = Int(k) {
                
                let point = FeedbackPoint(
                    index: index,
                    label: label,
                    value: value
                )
                tempPoints.append(point)
            }
        }
        
        feedbackPoints = tempPoints
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                self.showChart = true
            }
        }
    }
}
