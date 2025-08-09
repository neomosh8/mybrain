
import SwiftUI
import Combine
import NaturalLanguage

struct AnimatedSubtitleView: View {
    @ObservedObject var listeningViewModel: ListeningViewModel
    
    let currentTime: TimeInterval
    let thoughtId: String
    let chapterNumber: Int
        
    @State private var paragraphs: [[WordData]] = []
    @State private var wordFrames: [Int: CGRect] = [:]
    @State private var highlightFrame: CGRect = .zero
        
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
                if newIndex >= 15 {
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
        .onChange(of: wordFrames) { _, _ in
            updateHighlightFrame()
        }
    }
    
    private func buildParagraphs() {
        let allText = listeningViewModel.allWords.map { $0.text }.joined(separator: " ")
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = allText
        
        let commonUppercaseWords: Set<String> = ["I", "I'm", "I'll", "I've", "I'd", "Dr", "Mr", "Mrs", "Ms"]
        
        var currentParagraph: [WordData] = []
        var newParagraphs: [[WordData]] = []
        var textIndex = allText.startIndex
        
        for (index, wordTimestamp) in listeningViewModel.allWords.enumerated() {
            let wordData = WordData(
                originalIndex: index,
                text: wordTimestamp.text,
                startTime: wordTimestamp.start,
                endTime: wordTimestamp.end
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
    let paragraphs: [[WordData]]
    let currentWordIndex: Int
    @Binding var wordFrames: [Int: CGRect]
    @Binding var highlightFrame: CGRect
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if currentWordIndex >= 0 && highlightFrame != .zero {
                HighlightOverlay(frame: highlightFrame)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    FlowLayout(spacing: 4, lineSpacing: 6) {
                        ForEach(paragraph) { wordData in
                            Text(wordData.text)
                                .font(.body)
                                .foregroundColor(wordData.originalIndex == currentWordIndex ? .white : .primary)
                                .captureWordFrame(index: wordData.originalIndex, in: "subtitleContainer")
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
        .onPreferenceChange(WordFrameKey.self) { frames in
            wordFrames = frames
        }
    }
}
