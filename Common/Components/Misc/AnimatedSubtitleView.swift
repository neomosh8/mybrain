
import SwiftUI
import Combine

struct AnimatedSubtitleView: View {
    @ObservedObject var subtitleViewModel: SubtitleViewModel
    let currentTime: TimeInterval
    let thoughtId: String
    let chapterNumber: Int
    
    private let feedbackService: any FeedbackServiceProtocol
    
    @State private var paragraphs: [[SubtitleWordData]] = []
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var highlightFrame: CGRect = .zero
    
    init(
        subtitleViewModel: SubtitleViewModel,
        currentTime: TimeInterval,
        thoughtId: String,
        chapterNumber: Int,
        feedbackService: any FeedbackServiceProtocol = FeedbackService.shared
    ) {
        self.subtitleViewModel = subtitleViewModel
        self.currentTime = currentTime
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self.feedbackService = feedbackService
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if subtitleViewModel.isLoading {
                    ProgressView("Loading subtitles...")
                        .padding()
                } else {
                    SubtitleTextView(
                        paragraphs: paragraphs,
                        currentWordIndex: subtitleViewModel.currentWordIndex,
                        wordFrames: $wordFrames,
                        highlightFrame: $highlightFrame
                    )
                    .padding()
                }
            }
            .onChange(of: subtitleViewModel.currentWordIndex) { _, newIndex in
                if newIndex >= 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                    
                    // Send feedback
                    if newIndex < subtitleViewModel.allWords.count {
                        let word = subtitleViewModel.allWords[newIndex].text
                        sendFeedback(for: word)
                    }
                }
                updateHighlightFrame()
            }
            .onChange(of: subtitleViewModel.allWords) { _, _ in
                buildParagraphs()
            }
            .onAppear {
                buildParagraphs()
            }
        }
    }
    
    private func buildParagraphs() {
        let wordsPerParagraph = 15
        var currentParagraph: [SubtitleWordData] = []
        var newParagraphs: [[SubtitleWordData]] = []

        for (index, wordTimestamp) in subtitleViewModel.allWords.enumerated() {
            print("🕐 Word \(index): '\(wordTimestamp.text)' [\(wordTimestamp.start) - \(wordTimestamp.end)]") // 👈 Debug line

            let wordData = SubtitleWordData(
                text: wordTimestamp.text,
                startTime: wordTimestamp.start,
                endTime: wordTimestamp.end,
                originalIndex: index
            )

            currentParagraph.append(wordData)

            if currentParagraph.count >= wordsPerParagraph {
                newParagraphs.append(currentParagraph)
                currentParagraph = []
            }
        }

        if !currentParagraph.isEmpty {
            newParagraphs.append(currentParagraph)
        }

        paragraphs = newParagraphs
    }
    
    private func updateHighlightFrame() {
        guard subtitleViewModel.currentWordIndex >= 0,
              let frame = wordFrames[subtitleViewModel.currentWordIndex] else {
            highlightFrame = .zero
            return
        }
        highlightFrame = frame
    }
    
    private func sendFeedback(for word: String) {
        Task.detached(priority: .background) {
            let result = await feedbackService.submitFeedback(
                thoughtId: thoughtId,
                chapterNumber: chapterNumber,
                word: word
            )
            
            switch result {
            case .success(_):
                break
            case .failure(let error):
                print("Subtitle feedback submission failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Views
struct SubtitleTextView: View {
    let paragraphs: [[SubtitleWordData]]
    let currentWordIndex: Int
    @Binding var wordFrames: [Int: CGRect]
    @Binding var highlightFrame: CGRect
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Animated highlight background
            if currentWordIndex >= 0 && highlightFrame != .zero {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.cyan]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .opacity(0.8)
                    .frame(width: highlightFrame.width + 5, height: highlightFrame.height + 3)
                    .position(x: highlightFrame.midX, y: highlightFrame.midY)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: highlightFrame)
            }
            
            // Text content with FlowLayout
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    FlowLayout(spacing: 4, lineSpacing: 6) {
                        ForEach(paragraph) { wordData in
                            Text(getModifiedText(for: wordData))
                                .font(.body)
                                .foregroundColor(wordData.originalIndex == currentWordIndex ? .white : .primary)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .preference(key: SubtitleWordFrameKey.self, value: [wordData.originalIndex: proxy.frame(in: .named("subtitleContainer"))])
                                    }
                                )
                                .id(wordData.originalIndex)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .coordinateSpace(name: "subtitleContainer")
        .onPreferenceChange(SubtitleWordFrameKey.self) { frames in
            wordFrames = frames
        }
    }
    
    private func getModifiedText(for wordData: SubtitleWordData) -> String {
        return wordData.text + " "
    }
}

struct SubtitleWordData: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let originalIndex: Int
}

struct SubtitleWordFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
