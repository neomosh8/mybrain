import SwiftUI
import NaturalLanguage

struct AnimatedSubtitleView: View {
    @ObservedObject var listeningViewModel: ListeningViewModel
    
    let thoughtId: String
    let chapterNumber: Int
    
    @State private var paragraphs: [[WordData]] = []
    
    init(
        listeningViewModel: ListeningViewModel,
        thoughtId: String,
        chapterNumber: Int,
    ) {
        self.listeningViewModel = listeningViewModel
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AnimatedWordsView(
                    paragraphs: paragraphs,
                    currentWordIndex: listeningViewModel.currentWordIndex,
                    coordinateSpaceName: "subtitleContainer",
                    showOverlay: listeningViewModel.currentWordIndex >= 0,
                    wordFont: .body,
                    spacing: 4,
                    lineSpacing: 6,
                    bottomPadding: 50
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
}
