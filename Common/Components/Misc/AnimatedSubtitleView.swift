import SwiftUI
import Combine

// MARK: - Animated Subtitle View
struct AnimatedSubtitleView: View {
    @ObservedObject var subtitleViewModel: SubtitleViewModel

    let currentTime: TimeInterval
    let thoughtId: String
    let chapterNumber: Int
    
    // Dependencies
    private let feedbackService: any FeedbackServiceProtocol
    
    @State private var currentWordIndex: Int = -1
    @State private var paragraphs: [[SubtitleWordData]] = []
    @State private var allWords: [SubtitleWordData] = []
    @State private var hasSetupContent: Bool = false
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var highlightFrame: CGRect = .zero
    
    // MARK: - Initialization
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
                SubtitleTextView(
                    paragraphs: paragraphs,
                    currentWordIndex: currentWordIndex,
                    wordFrames: $wordFrames,
                    highlightFrame: $highlightFrame
                )
                .padding()
                .padding(.bottom, 20)
            }
            .onChange(of: currentTime) { _, newTime in
                updateCurrentWord(for: newTime)
            }
            .onChange(of: currentWordIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < allWords.count {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                    
                    // Send feedback for the current word
                    let word = allWords[newIndex].text
                    sendFeedback(for: word)
                }
                updateHighlightFrame()
            }
            .onChange(of: subtitleViewModel.segments) { _, _ in
                buildCombinedContent()
            }
            .onAppear {
                buildCombinedContent()
            }
        }
    }
    
    private func updateHighlightFrame() {
        guard currentWordIndex >= 0,
              let frame = wordFrames[currentWordIndex] else {
            highlightFrame = .zero
            return
        }
        highlightFrame = frame
    }
}

// MARK: - Content Setup
private extension AnimatedSubtitleView {
    func buildCombinedContent() {
        paragraphs = []
        allWords = []
        
        // Collect all words from all loaded segments, sorted by time
        var combinedWords: [WordTimestamp] = []

        
         for segmentData in subtitleViewModel.loadedSegmentData {
             combinedWords.append(contentsOf: segmentData.words)
         }
        
        
        // If no words available, return early
        guard !combinedWords.isEmpty else { return }
        
        // Sort words by start time to ensure proper order
        combinedWords.sort { $0.start < $1.start }
        
        
        // Group words into paragraphs
        let wordsPerParagraph = 15
        var currentParagraph: [SubtitleWordData] = []
        
        for (index, wordTimestamp) in combinedWords.enumerated() {
            let wordData = SubtitleWordData(
                text: wordTimestamp.text,
                startTime: wordTimestamp.start,
                endTime: wordTimestamp.end,
                originalIndex: index
            )
            
            currentParagraph.append(wordData)
            allWords.append(wordData)
            
            // Create new paragraph when reaching word limit
            if currentParagraph.count >= wordsPerParagraph {
                paragraphs.append(currentParagraph)
                currentParagraph = []
            }
        }
        
        // Add remaining words as final paragraph
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }
        
        // Update current word for current time
        updateCurrentWord(for: currentTime)
    }
    
    func updateCurrentWord(for time: TimeInterval) {
        // Find the word that should be highlighted at current time
        let newIndex = allWords.firstIndex { word in
            time >= word.startTime && time <= word.endTime
        } ?? -1
        
        if newIndex != currentWordIndex {
            currentWordIndex = newIndex
        }
    }
}

// MARK: - Feedback Methods
private extension AnimatedSubtitleView {
    func sendFeedback(for word: String) {
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

// MARK: - Supporting Data Models
struct SubtitleWordData: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let originalIndex: Int
}

// MARK: - Subtitle Text View (matches WordByWordTextView style)
struct SubtitleTextView: View {
    let paragraphs: [[SubtitleWordData]]
    let currentWordIndex: Int
    @Binding var wordFrames: [Int: CGRect]
    @Binding var highlightFrame: CGRect
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Animated highlight background (same as reading mode)
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
            
            // Text content with FlowLayout (same as reading mode)
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
            .coordinateSpace(name: "subtitleContainer")
            .onPreferenceChange(SubtitleWordFrameKey.self) { frames in
                wordFrames = frames
                updateHighlightFrame()
            }
        }
    }
    
    private func getModifiedText(for wordData: SubtitleWordData) -> String {
        return wordData.text + " "
    }
    
    private func updateHighlightFrame() {
        guard currentWordIndex >= 0,
              let frame = wordFrames[currentWordIndex] else {
            highlightFrame = .zero
            return
        }
        highlightFrame = frame
    }
}

// MARK: - Preference Key for word frames
struct SubtitleWordFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
