import SwiftUI
import NaturalLanguage

struct AnimatedParagraphView: View {
    let htmlString: String
    let thoughtId: String
    let chapterNumber: Int
    let wordInterval: TimeInterval
    let isCurrentChapter: Bool
    
    var onFinished: () -> Void
    var onHalfway: () -> Void
    
    // Dependencies
    private let feedbackService: any FeedbackServiceProtocol
    
    @State private var attributedContent: AttributedString = AttributedString()
    @State private var wordRanges: [(range: Range<AttributedString.Index>, word: String)] = []
    @State private var currentWordIndex: Int = 0
    @State private var isAnimating: Bool = false
    @State private var animationTimer: Timer?
    @State private var hasSetupContent: Bool = false
    
    // MARK: - Initialization
    init(
        htmlString: String,
        thoughtId: String,
        chapterNumber: Int,
        wordInterval: TimeInterval = 0.3,
        isCurrentChapter: Bool = false,
        feedbackService: any FeedbackServiceProtocol = FeedbackService.shared,
        onFinished: @escaping () -> Void = {},
        onHalfway: @escaping () -> Void = {}
    ) {
        self.htmlString = htmlString
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self.wordInterval = wordInterval
        self.isCurrentChapter = isCurrentChapter
        self.feedbackService = feedbackService
        self.onFinished = onFinished
        self.onHalfway = onHalfway
    }
    
    var body: some View {
        ScrollView {
            Text(buildHighlightedText())
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .onAppear {
            if !hasSetupContent {
                setupContent()
                hasSetupContent = true
            }
        }
        .onChange(of: isCurrentChapter) { _, newValue in
            if newValue && !isAnimating && !wordRanges.isEmpty {
                startAnimation()
            } else if !newValue && isAnimating {
                stopAnimation()
            }
        }
        .onChange(of: wordInterval) { _, _ in
            if isAnimating {
                animationTimer?.invalidate()
                animationTimer = nil
                
                resumeAnimationFromCurrentPosition()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func buildHighlightedText() -> AttributedString {
        var result = attributedContent
        
        // Reset all highlighting first
        for range in wordRanges {
            result[range.range].backgroundColor = nil
        }
        
        // Apply current word highlighting
        if isAnimating && currentWordIndex < wordRanges.count {
            let currentRange = wordRanges[currentWordIndex].range
            result[currentRange].backgroundColor = Color.blue
            result[currentRange].foregroundColor = Color.white
        }
        
        return result
    }
    
    private func setupContent() {
        // Parse HTML content preserving formatting
        parseHTMLContent()
        
        // Only start animation if this is the current chapter
        if isCurrentChapter && !wordRanges.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimation()
            }
        }
    }
    
    private func parseHTMLContent() {
        guard let data = htmlString.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            // Parse HTML to NSAttributedString first
            let nsAttributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Convert to SwiftUI AttributedString
            if let swiftUIAttributedString = try? AttributedString(nsAttributedString, including: \.uiKit) {
                attributedContent = swiftUIAttributedString
                overrideFontFamilyOnly()
                extractWordRanges()
            } else {
                // Fallback: create plain AttributedString
                let plainText = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                attributedContent = AttributedString(plainText)
                extractWordRanges()
            }
        } catch {
            print("Error parsing HTML: \(error)")
            // Fallback to plain text
            let plainText = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            attributedContent = AttributedString(plainText)
            extractWordRanges()
        }
    }
    
    private func overrideFontFamilyOnly() {
        // Only change font family to system font, preserve size/weight/style from HTML
        for run in attributedContent.runs {
            let runRange = run.range
            
            if let originalFont = run.uiKit.font {
                // Get original font characteristics
                let originalSize = originalFont.pointSize
                let traits = originalFont.fontDescriptor.symbolicTraits
                
                // Create system font with same characteristics
                var weight: Font.Weight = .regular
                var isItalic = false
                
                if traits.contains(.traitBold) {
                    weight = .bold
                }
                if traits.contains(.traitItalic) {
                    isItalic = true
                }
                
                // Apply system font with preserved characteristics
                var newFont = Font.system(size: originalSize, weight: weight)
                if isItalic {
                    newFont = newFont.italic()
                }
                
                attributedContent[runRange].font = newFont
            }
        }
    }
    
    private func extractWordRanges() {
        wordRanges.removeAll()
        
        let text = String(attributedContent.characters)
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        
        let fullRange = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: fullRange, unit: .word, scheme: .tokenType) { _, tokenRange in
            let word = String(text[tokenRange]).trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            
            // Only include meaningful words
            if word.count > 1 && word.rangeOfCharacter(from: .alphanumerics) != nil {
                // Convert String range to AttributedString range
                if let attributedRange = Range(tokenRange, in: attributedContent) {
                    wordRanges.append((range: attributedRange, word: word))
                }
            }
            return true
        }
    }
    
    private func startAnimation() {
        guard !wordRanges.isEmpty else {
            onFinished()
            return
        }
        
        isAnimating = true
        currentWordIndex = 0
        
        // Send feedback for first word
        // sendFeedback(for: wordRanges[0].word)
        
        // Start timer for subsequent words
        startAnimationTimer()
    }
    
    private func resumeAnimationFromCurrentPosition() {
        guard !wordRanges.isEmpty, isAnimating else { return }
        
        // Continue from current word position
        startAnimationTimer()
    }
    
    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: wordInterval, repeats: true) { [self] timer in
            DispatchQueue.main.async {
                currentWordIndex += 1
                
                if currentWordIndex >= wordRanges.count {
                    stopAnimation()
                    onFinished()
                } else {
                    // Send feedback for current word
                    // sendFeedback(for: wordRanges[currentWordIndex].word)
                    
                    // Check halfway point
                    let halfwayPoint = wordRanges.count / 2
                    if currentWordIndex == halfwayPoint {
                        onHalfway()
                    }
                }
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }
    
    private func sendFeedback(for word: String) {
        feedbackService.submitFeedbackSync(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: word
        )
        
        print("Feedback submitted for word: \(word)")
    }
}
