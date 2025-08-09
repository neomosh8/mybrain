
import SwiftUI
import Combine
import NaturalLanguage

struct AnimatedSubtitleView: View {
    @ObservedObject var listeningViewModel: ListeningViewModel
    
    let currentTime: TimeInterval
    let thoughtId: String
    let chapterNumber: Int
        
    @State private var paragraphs: [[SubtitleWordData]] = []
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var highlightFrame: CGRect = .zero
    
    @State private var wordBuffer: [String] = []
    private let batchSize = 10
    
    init(
        listeningViewModel: ListeningViewModel,
        currentTime: TimeInterval,
        thoughtId: String,
        chapterNumber: Int,
    ) {
        self.listeningViewModel = listeningViewModel
        self.currentTime = currentTime
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                SubtitleTextView(
                    paragraphs: paragraphs,
                    currentWordIndex: listeningViewModel.currentWordIndex,
                    wordFrames: $wordFrames,
                    highlightFrame: $highlightFrame
                )
                .padding()
            }
            .onChange(of: listeningViewModel.currentWordIndex) { _, newIndex in
                if newIndex >= 10 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
     
                if newIndex >= 0 && newIndex < listeningViewModel.allWords.count {
                    let word = listeningViewModel.allWords[newIndex].text
                    let feedbackValue = bluetoothService.processFeedback(word: word)
                    
                    feedbackBuffer.addFeedback(
                        word: word,
                        value: feedbackValue,
                        thoughtId: thoughtId,
                        chapterNumber: chapterNumber
                    )
                }

                
                updateHighlightFrame()
            }
            .onChange(of: listeningViewModel.allWords) { _, _ in
                buildParagraphs()
            }
            .onAppear {
                buildParagraphs()
            }
        }
    }
    
    private func buildParagraphs() {
        let allText = listeningViewModel.allWords.map { $0.text }.joined(separator: " ")
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = allText
        
        let commonUppercaseWords: Set<String> = ["I", "I'm", "I'll", "I've", "I'd", "Dr", "Mr", "Mrs", "Ms"]
        
        var currentParagraph: [SubtitleWordData] = []
        var newParagraphs: [[SubtitleWordData]] = []
        var textIndex = allText.startIndex
        
        for (index, wordTimestamp) in listeningViewModel.allWords.enumerated() {
            let wordData = SubtitleWordData(
                text: wordTimestamp.text,
                startTime: wordTimestamp.start,
                endTime: wordTimestamp.end,
                originalIndex: index
            )
            
            let word = wordTimestamp.text
            let firstChar = word.first
            let isUppercase = firstChar?.isUppercase == true
            
            if let wordRange = allText.range(of: word, range: textIndex..<allText.endIndex) {
                var shouldStartNewParagraph = false
                
                if isUppercase && !currentParagraph.isEmpty {
                    if commonUppercaseWords.contains(word) {
                        shouldStartNewParagraph = false
                    } else {
                        tagger.enumerateTags(in: wordRange, unit: .word, scheme: .nameType) { tag, _ in
                            if tag == .personalName || tag == .placeName || tag == .organizationName {
                                shouldStartNewParagraph = false
                            } else {
                                shouldStartNewParagraph = true
                            }
                            return false
                        }
                        
                        if shouldStartNewParagraph {
                            tagger.enumerateTags(in: wordRange, unit: .word, scheme: .lexicalClass) { tag, _ in
                                if tag == .noun && word.count > 3 {
                                    shouldStartNewParagraph = false
                                }
                                return false
                            }
                        }
                    }
                }
                
                if shouldStartNewParagraph {
                    newParagraphs.append(currentParagraph)
                    currentParagraph = []
                }
                
                textIndex = wordRange.upperBound
            }
            
            currentParagraph.append(wordData)
        }
        
        if !currentParagraph.isEmpty {
            newParagraphs.append(currentParagraph)
        }
        
        paragraphs = newParagraphs
    }
    
    private func updateHighlightFrame() {
        guard listeningViewModel.currentWordIndex >= 0,
              let frame = wordFrames[listeningViewModel.currentWordIndex] else {
            highlightFrame = .zero
            return
        }
        highlightFrame = frame
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
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .coordinateSpace(name: "subtitleContainer")
        .onPreferenceChange(SubtitleWordFrameKey.self) { frames in
            wordFrames = frames
        }
    }
    
    private func getModifiedText(for wordData: SubtitleWordData) -> String {
        return wordData.text
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


private extension AnimatedSubtitleView {
    func sendFeedback(for word: String, thoughtId: String, chapterNumber: Int) {
        let feedbackValue = bluetoothService.processFeedback(word: word)
        
        feedbackBuffer.addFeedback(
            word: word,
            value: feedbackValue,
            thoughtId: thoughtId,
            chapterNumber: chapterNumber
        )
    }
}
