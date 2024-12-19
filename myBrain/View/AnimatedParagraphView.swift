import SwiftUI

struct AnimatedParagraphView: View {
    let paragraph: String
    let backgroundColor: Color
    var wordInterval: Double
    let chapterIndex: Int
    let onHalfway: () -> Void
    let onFinished: () -> Void

    @State private var shownWordsCount = 0
    @State private var wordFrames: [CGRect] = []
    @State private var readyToAnimate = false
    @State private var scheduledTask: DispatchWorkItem?

    let customFont = UIFont(name: "Helvetica", size: 20) ?? UIFont.systemFont(ofSize: 20)
    let lineSpacingValue: CGFloat = 10

    var words: [String] {
        paragraph.components(separatedBy: " ")
    }

    var body: some View {
        let containerWidth = UIScreen.main.bounds.width - 32

        ZStack(alignment: .topLeading) {
            // Invisible text to define layout
            Text(paragraph)
                .font(.custom("Helvetica", size: 20))
                .lineSpacing(lineSpacingValue)
                .foregroundColor(.clear)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: containerWidth, alignment: .leading)

            // Overlay each word when ready
            if readyToAnimate {
                ForEach(Array(words.enumerated()), id: \.offset) { (index, word) in
                    let frame = wordFrames.indices.contains(index) ? wordFrames[index] : .zero
                    Text(word + (index < words.count - 1 ? " " : ""))
                        .font(.custom("Helvetica", size: 20))
                        .lineSpacing(lineSpacingValue)
                        .position(x: frame.midX, y: frame.midY)
                        .opacity(index < shownWordsCount ? 1 : 0)
                        .offset(y: index < shownWordsCount ? 0 : 10)
                        .animation(.easeOut(duration: 0.25), value: shownWordsCount)
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
        .onAppear {
            DispatchQueue.main.async {
                measureWords(paragraph: paragraph, font: customFont, lineSpacing: lineSpacingValue, width: containerWidth) { frames in
                    self.wordFrames = frames
                    self.readyToAnimate = true
                    self.startAnimation()
                }
            }
        }
        .onChange(of: wordInterval) { newValue in
            // If words are still being revealed and we have a scheduled next word,
            // cancel and reschedule with the updated interval.
            if shownWordsCount < words.count {
                scheduledTask?.cancel()
                scheduleNextWord()
            }
        }
    }

    private func startAnimation() {
        if words.isEmpty {
            onFinished()
            return
        }
        withAnimation {
            shownWordsCount = 1
        }
        scheduleNextWord()
    }

    private func scheduleNextWord() {
        guard shownWordsCount < words.count else {
            // All words revealed for this paragraph, trigger onFinished
            onFinished()
            return
        }

        let task = DispatchWorkItem {
            if shownWordsCount < words.count {
                withAnimation {
                    shownWordsCount += 1
                }

                // Check if we've reached the halfway point for subsequent chapters
                let halfwayPoint = words.count / 2
                if chapterIndex > 0 && shownWordsCount == halfwayPoint {
                    // At halfway for subsequent chapters, request the next chapter
                    onHalfway()
                }

                // Schedule next again
                scheduleNextWord()
            } else {
                // No more words to show
                onFinished()
            }
        }
        scheduledTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + wordInterval, execute: task)
    }

    private func measureWords(paragraph: String, font: UIFont, lineSpacing: CGFloat, width: CGFloat, completion: @escaping ([CGRect]) -> Void) {
        let wordsArray = paragraph.components(separatedBy: " ")

        let textStorage = NSTextStorage(string: paragraph)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        // Set font
        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: paragraph.utf16.count))

        // Set line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraph.utf16.count))

        // Force layout
        layoutManager.glyphRange(for: textContainer)

        var frames: [CGRect] = []
        var currentLocation = 0

        for (i, word) in wordsArray.enumerated() {
            let wordWithSpace = (i < wordsArray.count - 1) ? word + " " : word
            let wordRange = NSRange(location: currentLocation, length: wordWithSpace.utf16.count)
            currentLocation += wordWithSpace.utf16.count

            if let rect = boundingRect(for: wordRange, layoutManager: layoutManager, textContainer: textContainer) {
                frames.append(rect)
            } else {
                frames.append(.zero)
            }
        }

        completion(frames)
    }

    private func boundingRect(for range: NSRange, layoutManager: NSLayoutManager, textContainer: NSTextContainer) -> CGRect? {
        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return boundingRect.isEmpty ? nil : boundingRect
    }
}
