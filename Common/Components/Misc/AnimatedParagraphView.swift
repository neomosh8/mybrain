import SwiftUI
import NaturalLanguage

struct AnimatedParagraphView: UIViewRepresentable {
    let htmlString: String
    let thoughtId: String
    let chapterNumber: Int
    let wordInterval: TimeInterval
    
    var onFinished: () -> Void
    var onHalfway: () -> Void
    
    // Dependencies
    private let feedbackService: any FeedbackServiceProtocol
    
    // MARK: - Initialization
    init(
        htmlString: String,
        thoughtId: String,
        chapterNumber: Int,
        wordInterval: TimeInterval = 0.4,
        feedbackService: any FeedbackServiceProtocol = FeedbackService.shared,
        onFinished: @escaping () -> Void = {},
        onHalfway: @escaping () -> Void = {}
    ) {
        self.htmlString = htmlString
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self.wordInterval = wordInterval
        self.feedbackService = feedbackService
        self.onFinished = onFinished
        self.onHalfway = onHalfway
    }
    
    func makeUIView(context: Context) -> AnimatedTextView {
        let textView = AnimatedTextView()
        return textView
    }
    
    func updateUIView(_ uiView: AnimatedTextView, context: Context) {
        if uiView.currentContent != htmlString {
            uiView.configure(
                htmlString: htmlString,
                thoughtId: thoughtId,
                chapterNumber: chapterNumber,
                wordInterval: wordInterval,
                feedbackService: feedbackService,
                onFinished: onFinished,
                onHalfway: onHalfway
            )
        }
    }
}

// MARK: - AnimatedTextView

class AnimatedTextView: UITextView {
    private var wordInfo: [(range: NSRange, rect: CGRect?)] = []
    private var shownWordsCount = 0
    private var scheduledTask: DispatchWorkItem?
    private var animationFinished = false
    private var fullAttributedString: NSAttributedString?
    private var isAnimating = false
    
    // Configuration properties
    var currentContent: String = ""
    private var thoughtId: String = ""
    private var chapterNumber: Int = 0
    private var wordInterval: TimeInterval = 0.4
    private var feedbackService: (any FeedbackServiceProtocol)?
    private var onFinished: (() -> Void)?
    private var onHalfway: (() -> Void)?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        isEditable = false
        isSelectable = false
        backgroundColor = .clear
        textColor = .white
        font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textAlignment = .center
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
    }
    
    func configure(
        htmlString: String,
        thoughtId: String,
        chapterNumber: Int,
        wordInterval: TimeInterval,
        feedbackService: any FeedbackServiceProtocol,
        onFinished: @escaping () -> Void,
        onHalfway: @escaping () -> Void
    ) {
        stopAnimation()
        
        self.currentContent = htmlString
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self.wordInterval = wordInterval
        self.feedbackService = feedbackService
        self.onFinished = onFinished
        self.onHalfway = onHalfway
        
        setupAttributedText(from: htmlString)
        prepareAnimation()
        startAnimation()
    }
    
    private func stopAnimation() {
        scheduledTask?.cancel()
        scheduledTask = nil
        isAnimating = false
        animationFinished = false
        shownWordsCount = 0
    }
    
    private func setupAttributedText(from htmlString: String) {
        guard let data = htmlString.data(using: .utf8) else { return }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let attributedString = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Apply consistent styling
            let fullRange = NSRange(location: 0, length: attributedString.length)
            attributedString.addAttribute(.foregroundColor, value: UIColor.white, range: fullRange)
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 18, weight: .medium), range: fullRange)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 8
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            
            self.fullAttributedString = attributedString
            
        } catch {
            print("Error creating attributed string from HTML: \(error)")
            self.text = htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
    }
    
    private func prepareAnimation() {
        guard let fullString = fullAttributedString?.string else { return }
        
        let tokenRanges = tokenRanges(for: fullString)
        wordInfo = tokenRanges.map { range in
            let rect = boundingRect(for: range)
            return (range: range, rect: rect)
        }
        
        // Start with all text hidden
        updateVisibleText()
    }
    
    private func updateVisibleText() {
        guard let mutableAttrString = fullAttributedString?.mutableCopy() as? NSMutableAttributedString else { return }
        
        let fullRange = NSRange(location: 0, length: mutableAttrString.length)
        mutableAttrString.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRange)
        
        // Make visible words white
        for i in 0..<min(shownWordsCount, wordInfo.count) {
            let range = wordInfo[i].range
            mutableAttrString.addAttribute(.foregroundColor, value: UIColor.white, range: range)
        }
        
        self.attributedText = mutableAttrString
    }
    
    private func boundingRect(for range: NSRange) -> CGRect? {
        guard range.location != NSNotFound && range.length > 0 else { return nil }
        
        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return boundingRect.isEmpty ? nil : boundingRect
    }

    private func startAnimation() {
        guard wordInfo.count > 0, !isAnimating else {
            onFinished?()
            return
        }
        
        isAnimating = true
        shownWordsCount = 1
        updateVisibleText()
        sendFeedbackForWord(at: 0)
        scheduleNextWord()
    }

    private func scheduleNextWord() {
        guard isAnimating, shownWordsCount < wordInfo.count else {
            animationFinished = true
            isAnimating = false
            onFinished?()
            return
        }
        
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, self.isAnimating else { return }
            
            self.shownWordsCount += 1
            self.updateVisibleText()
            self.sendFeedbackForWord(at: self.shownWordsCount - 1)

            let halfwayPoint = (self.wordInfo.count + 1) / 2
            if self.shownWordsCount == halfwayPoint {
                self.onHalfway?()
            }
            
            // Continue animation
            self.scheduleNextWord()
        }
        
        self.scheduledTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + wordInterval, execute: task)
    }

    private func sendFeedbackForWord(at index: Int) {
        guard index >= 0 && index < wordInfo.count,
              let feedbackService = feedbackService,
              let fullAttributedString = fullAttributedString else { return }
        
        let range = wordInfo[index].range
        let subAttr = fullAttributedString.attributedSubstring(from: range)
        let plainWord = subAttr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !plainWord.isEmpty,
              plainWord.count > 1,
              containsAlphanumeric(plainWord) else { return }
        
        feedbackService.submitFeedbackSync(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: plainWord
        )
        
        print("Feedback submitted for word: \(plainWord)")
    }
    
    private func containsAlphanumeric(_ string: String) -> Bool {
        return string.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil
    }
}

// MARK: - NLTagger Utility
extension AnimatedTextView {
    private func tokenRanges(for string: String) -> [NSRange] {
        var results: [NSRange] = []
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = string

        let fullRange = string.startIndex..<string.endIndex

        tagger.enumerateTags(in: fullRange, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let start = tokenRange.lowerBound
            let end   = tokenRange.upperBound
            let nsRange = NSRange(start..<end, in: string)
            if nsRange.length > 0 {
                results.append(nsRange)
            }
            return true
        }
        return results
    }
}
