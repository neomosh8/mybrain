import SwiftUI
import NaturalLanguage

struct AnimatedParagraphView: View {
    // MARK: - Input
    let paragraph: String
    let backgroundColor: Color
    var wordInterval: Double
    let chapterIndex: Int
    let thoughtId: String
    let chapterNumber: Int
    private let networkService = NetworkServiceManager.shared
    
    let onHalfway: () -> Void
    let onFinished: () -> Void
    @State private var totalTextHeight: CGFloat = 0
    @Binding var currentChapterIndex: Int?

    // MARK: - State
    @State private var shownWordsCount = 0
    @State private var wordInfo: [(range: NSRange, rect: CGRect)] = []
    @State private var fullAttributedString: NSAttributedString?
    
    @State private var readyToAnimate = false
    @State private var scheduledTask: DispatchWorkItem?
    @State private var animationFinished = false

    // MARK: - Body
    var body: some View {
        let containerWidth = UIScreen.main.bounds.width - 32

        ZStack(alignment: .topLeading) {
            // 1) Invisible text for layout
            Text(fullAttributedString?.string ?? "")
                // Make sure the "invisible" text uses same font metrics
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.clear)
                .frame(width: containerWidth, alignment: .leading)
                .lineLimit(nil)

            // 2) Show each word as an attributed substring
            if readyToAnimate {
                ForEach(wordInfo.indices, id: \.self) { index in
                    let (range, rect) = wordInfo[index]
                    
                    if let subAttr = fullAttributedString?.attributedSubstring(from: range) {
                        // Convert NSAttributedString -> SwiftUI AttributedString
                        if let swiftUIAttrString = try? AttributedString(subAttr, including: \.uiKit) {
                            Text(swiftUIAttrString)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.black)
                                .position(x: rect.midX, y: rect.midY)
                                .opacity(index < shownWordsCount ? 1 : 0)
                                .offset(y: index < shownWordsCount ? 0 : 10)
                                .animation(.easeOut(duration: 0.25), value: shownWordsCount)
                        } else {
                            // Fallback plain text
                            Text(subAttr.string)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.black)
                                .position(x: rect.midX, y: rect.midY)
                                .opacity(index < shownWordsCount ? 1 : 0)
                                .offset(y: index < shownWordsCount ? 0 : 10)
                                .animation(.easeOut(duration: 0.25), value: shownWordsCount)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: containerWidth, height: totalTextHeight + 40)  // <–– FORCE HEIGHT

        .background(Color.clear)
        .cornerRadius(6)
        .onAppear {
            loadHTMLAndMeasure(containerWidth: containerWidth)
        }
        .onChange(of: wordInterval) { _, _ in
            if shownWordsCount < wordInfo.count {
                scheduledTask?.cancel()
                scheduleNextWord()
            }
        }
        .onChange(of: currentChapterIndex) { _, newValue in
            if newValue == chapterIndex && !animationFinished {
                startAnimation()
            }
        }
        .onDisappear {
            scheduledTask?.cancel()
            shownWordsCount = 0
            animationFinished = false
        }
    }
}

// MARK: - Main Logic
extension AnimatedParagraphView {
    private func loadHTMLAndMeasure(containerWidth: CGFloat) {
        // 1) Parse HTML -> NSAttributedString
        guard let data = paragraph.data(using: .utf8) else { return }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        let parsedAttrString: NSAttributedString
        if let attrStr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            parsedAttrString = attrStr
        } else {
            parsedAttrString = NSAttributedString(string: paragraph)
        }

        self.fullAttributedString = parsedAttrString

        // 2) Measure words
        measureWords(attrStr: parsedAttrString, width: containerWidth) { info in
            self.wordInfo = info
            self.readyToAnimate = true
            
            // Start animation if this is the active chapter
            if currentChapterIndex == chapterIndex {
                self.startAnimation()
            }
        }
    }

    private func measureWords(attrStr: NSAttributedString,
                              width: CGFloat,
                              completion: @escaping ([(range: NSRange, rect: CGRect)]) -> Void) {
        let textStorage = NSTextStorage(attributedString: attrStr)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        _ = layoutManager.glyphRange(for: textContainer)

        // B) Enumerate words
        let fullString = attrStr.string
        let allWordRanges = self.tokenRanges(for: fullString)

        var result: [(range: NSRange, rect: CGRect)] = []
        for range in allWordRanges {
            if let rect = boundingRect(for: range, layoutManager: layoutManager, textContainer: textContainer) {
                result.append((range, rect))
            } else {
                result.append((range, .zero))
            }
        }

        // Compute the largest maxY
        let maxBottom = result.map { $0.rect.maxY }.max() ?? 0
        // Store it in a @State var so we can use it for frame height
        DispatchQueue.main.async {
            self.totalTextHeight = maxBottom
        }

        completion(result)
    }


    private func boundingRect(for range: NSRange,
                              layoutManager: NSLayoutManager,
                              textContainer: NSTextContainer) -> CGRect? {
        var glyphRange = NSRange()
        guard range.location != NSNotFound && range.length > 0 else { return nil }
        
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return boundingRect.isEmpty ? nil : boundingRect
    }

    private func startAnimation() {
        guard wordInfo.count > 0 else {
            onFinished()
            return
        }
        withAnimation {
            shownWordsCount = 1
        }
        sendFeedbackForWord(at: 0)
        scheduleNextWord()
    }

    private func scheduleNextWord() {
        guard shownWordsCount < wordInfo.count else {
            animationFinished = true
            onFinished()
            return
        }
        let task = DispatchWorkItem {
            if shownWordsCount < wordInfo.count {
                withAnimation {
                    shownWordsCount += 1
                }
                self.sendFeedbackForWord(at: shownWordsCount - 1)

                let halfwayPoint = (wordInfo.count + 1) / 2
                if shownWordsCount == halfwayPoint {
                    self.onHalfway()
                }
                self.scheduleNextWord()
            } else {
                self.animationFinished = true
                self.onFinished()
            }
        }
        self.scheduledTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + wordInterval, execute: task)
    }

    private func sendFeedbackForWord(at index: Int) {
        guard index >= 0 && index < wordInfo.count else { return }
        let range = wordInfo[index].range
        if let subAttr = fullAttributedString?.attributedSubstring(from: range) {
            let plainWord = subAttr.string.trimmingCharacters(in: .whitespacesAndNewlines)

            networkService.webSocket.sendFeedback(
                thoughtId: thoughtId,
                chapterNumber: chapterNumber,
                word: plainWord,
                value: BluetoothService.shared.processFeedback(word: plainWord)
            )
        }
    }
}

// MARK: - NLTagger Utility
extension AnimatedParagraphView {
    private func tokenRanges(for string: String) -> [NSRange] {
        var results: [NSRange] = []
        _ = string as NSString

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
