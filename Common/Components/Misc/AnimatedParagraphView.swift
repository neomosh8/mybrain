import SwiftUI
import Combine
import NaturalLanguage

// MARK: - Main View
struct AnimatedParagraphView: View {
    @Binding var wordInterval: TimeInterval
    
    let htmlString: String
    let thoughtId: String
    let chapterNumber: Int
    let isCurrentChapter: Bool
    
    var onFinished: () -> Void
    var onHalfway: () -> Void
    
    @State private var attributedContent: AttributedString = AttributedString()
    @State private var wordRanges: [(range: Range<AttributedString.Index>, word: String)] = []
    @State private var currentWordIndex: Int = -1
    @State private var isAnimating: Bool = false
    @State private var animationTimer: DispatchSourceTimer?
    @State private var hasSetupContent: Bool = false
    
    @State private var isPaused: Bool = false
    @State private var playbackObserver: AnyCancellable?
    
    @State private var paragraphs: [[WordData]] = []
    
    // MARK: - Initialization
    init(
        htmlString: String,
        thoughtId: String,
        chapterNumber: Int,
        wordInterval: Binding<TimeInterval>,
        isCurrentChapter: Bool = false,
        onFinished: @escaping () -> Void = {},
        onHalfway: @escaping () -> Void = {}
    ) {
        self.htmlString = htmlString
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self._wordInterval = wordInterval
        self.isCurrentChapter = isCurrentChapter
        self.onFinished = onFinished
        self.onHalfway = onHalfway
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            AnimatedWordsView(
                paragraphs: paragraphs,
                currentWordIndex: currentWordIndex,
                coordinateSpaceName: "container",
                showOverlay: isAnimating,
                wordFont: nil,
                spacing: 4,
                lineSpacing: 6,
                bottomPadding: 70
            )
            .padding()
        }
        .onAppear {
            if !hasSetupContent {
                setupContent()
                hasSetupContent = true
            }
            setupPlaybackObserver()
        }
        .onChange(of: isCurrentChapter) { _, newValue in
            if newValue && !isAnimating && !wordRanges.isEmpty && !isPaused {
                startAnimation()
            } else if !newValue && isAnimating {
                stopAnimation()
            }
        }
        .onChange(of: wordInterval) { _, _ in
            if isAnimating && !isPaused {
                animationTimer?.cancel()
                animationTimer = nil
                resumeAnimationFromCurrentPosition()
            }
        }
        .onChange(of: currentWordIndex) { _, newIndex in
            if newIndex >= 0 && newIndex < wordRanges.count {
                sendFeedback(word: wordRanges[newIndex].word, thoughtId: thoughtId, chapterNumber: chapterNumber)
            }
        }
        .onDisappear {
            stopAnimation()
            playbackObserver?.cancel()
        }
    }
}

// MARK: - Content Setup Methods
private extension AnimatedParagraphView {
    func setupContent() {
        guard let data = htmlString.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let nsAttributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            
            if let swiftUIAttributedString = try? AttributedString(nsAttributedString, including: \.uiKit) {
                attributedContent = swiftUIAttributedString
                overrideFontFamilyOnly()
                extractWordRanges()
                buildWordDataArray()
            } else {
                let plainText = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                attributedContent = AttributedString(plainText)
                extractWordRanges()
                buildWordDataArray()
            }
        } catch {
            let plainText = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            attributedContent = AttributedString(plainText)
            extractWordRanges()
            buildWordDataArray()
        }
        
        
        if isCurrentChapter && !wordRanges.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimation()
            }
        }
    }
    
    func overrideFontFamilyOnly() {
        for run in attributedContent.runs {
            let runRange = run.range

            if let originalFont = run.uiKit.font {
                let originalSize = originalFont.pointSize
                let traits = originalFont.fontDescriptor.symbolicTraits

                var weight: Font.Weight = .regular
                var isItalic = false

                if traits.contains(.traitBold)   { weight = .bold }
                if traits.contains(.traitItalic) { isItalic = true }

                let newFont = Font.system(size: originalSize, weight: weight)
                attributedContent[runRange].font = newFont

                if isItalic {
                    var intents = attributedContent[runRange].inlinePresentationIntent
                    intents?.insert(.emphasized)
                    attributedContent[runRange].inlinePresentationIntent = intents
                }
            }
        }
    }

    func extractWordRanges() {
        wordRanges.removeAll()
        
        let text = String(attributedContent.characters)
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        
        let fullRange = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: fullRange, unit: .word, scheme: .tokenType) { _, tokenRange in
            let raw = String(text[tokenRange])
            let word = raw.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            
            if word.rangeOfCharacter(from: .letters) != nil {
                if let attributedRange = Range(tokenRange, in: attributedContent) {
                    wordRanges.append((range: attributedRange, word: word))
                }
            }
            return true
        }
    }
    
    func buildWordDataArray() {
        paragraphs = []
        
        var currentParagraph: [WordData] = []
        
        for (index, wordRange) in wordRanges.enumerated() {
            if index > 0 {
                let prevRange = wordRanges[index - 1].range
                let between = attributedContent.characters[prevRange.upperBound..<wordRange.range.lowerBound]
                if between.contains("\n") {
                    if !currentParagraph.isEmpty {
                        paragraphs.append(currentParagraph)
                    }
                    currentParagraph = []
                }
            }
            
            let substring = AttributedString(attributedContent[wordRange.range])
            let wordText = String(attributedContent.characters[wordRange.range])
            let attrs = substring.runs.first?.attributes ?? AttributeContainer()
            let data = WordData(originalIndex: index, text: wordText, attributes: attrs)
            
            currentParagraph.append(data)
        }
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }
    }
}

// MARK: - Playback Observer Methods
private extension AnimatedParagraphView {
    func setupPlaybackObserver() {
        playbackObserver = NotificationCenter.default
            .publisher(for: .readingPlaybackStateChanged)
            .sink { notification in
                guard let isPlaying = notification.userInfo?["isPlaying"] as? Bool else { return }
                
                if isPlaying && isPaused && isCurrentChapter {
                    isPaused = false
                    resumeAnimationFromCurrentPosition()
                } else if !isPlaying && isAnimating {
                    isPaused = true
                    pauseAnimation()
                }
            }
    }
}

// MARK: - Animation Control Methods
private extension AnimatedParagraphView {
    func startAnimation() {
        guard !wordRanges.isEmpty else {
            onFinished()
            return
        }
        
        isAnimating = true
        isPaused = false
        
        startAnimationTimer()
    }
    
    func resumeAnimationFromCurrentPosition() {
        guard !wordRanges.isEmpty, !isPaused else { return }
        
        if !isAnimating {
            isAnimating = true
        }
        
        startAnimationTimer()
    }
    
    func startAnimationTimer() {
        animationTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now() + wordInterval, repeating: wordInterval)
        
        timer.setEventHandler {
            DispatchQueue.main.async {                
                self.currentWordIndex += 1
                
                if self.currentWordIndex >= self.wordRanges.count {
                    self.stopAnimation()
                    self.onFinished()
                    return
                }
                
                let halfwayPoint = self.wordRanges.count / 2
                if self.currentWordIndex == halfwayPoint {
                    self.onHalfway()
                }
            }
        }
        
        timer.resume()
        animationTimer = timer
    }
    
    func pauseAnimation() {
        animationTimer?.cancel()
        animationTimer = nil
    }
    
    func stopAnimation() {
        animationTimer?.cancel()
        animationTimer = nil
        isAnimating = false
        isPaused = false
    }
}

