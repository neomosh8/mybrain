import SwiftUI

struct AnimatedParagraphView: View {
    let paragraph: String
    let backgroundColor: Color
    var wordInterval: Double
    let chapterIndex: Int
    let thoughtId: Int
    let chapterNumber: Int
    let socketViewModel: WebSocketViewModel
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
            print("[AnimatedParagraphView] onAppear - measuring words...")
            DispatchQueue.main.async {
                measureWords(paragraph: paragraph, font: customFont, lineSpacing: lineSpacingValue, width: containerWidth) { frames in
                    print("[AnimatedParagraphView] Word frames measured: \(frames.count) frames.")
                    self.wordFrames = frames
                    self.readyToAnimate = true
                    self.startAnimation()
                }
            }
        }
        .onChange(of: wordInterval) { newValue in
            if shownWordsCount < words.count {
                print("[AnimatedParagraphView] Word interval changed to \(newValue). Rescheduling next word.")
                scheduledTask?.cancel()
                scheduleNextWord()
            }
        }
        .onDisappear {
            // Cancel any scheduled animations
            scheduledTask?.cancel()
            shownWordsCount = 0
            print("[AnimatedParagraphView] onDisappear - scheduled task cancelled and word count reset")
        }
    }

    private func startAnimation() {
        print("[AnimatedParagraphView] startAnimation called.")
        if words.isEmpty {
            print("[AnimatedParagraphView] Paragraph is empty, calling onFinished.")
            onFinished()
            return
        }
        withAnimation {
            shownWordsCount = 1
        }
        let firstWord = words[0]
        print("[AnimatedParagraphView] Showing first word: '\(firstWord)'")
        sendFeedbackForWord(firstWord)
        scheduleNextWord()
    }

    private func scheduleNextWord() {
        guard shownWordsCount < words.count else {
            print("[AnimatedParagraphView] All words shown, calling onFinished.")
            onFinished()
            return
        }

        let task = DispatchWorkItem {
            if shownWordsCount < words.count {
                withAnimation {
                    self.shownWordsCount += 1
                }
                let revealedWord = self.words[self.shownWordsCount - 1]
                print("[AnimatedParagraphView] Revealed word #\(self.shownWordsCount): '\(revealedWord)'")

                self.sendFeedbackForWord(revealedWord)

                // Halfway logic
                let halfwayPoint = (self.words.count + 1) / 2
                if  self.shownWordsCount == halfwayPoint {
                    print("[AnimatedParagraphView] Reached halfway point at word #\(self.shownWordsCount), calling onHalfway.")
                    self.onHalfway()
                }

                // Schedule next word
                self.scheduleNextWord()
            } else {
                print("[AnimatedParagraphView] No more words to show, calling onFinished.")
                self.onFinished()
            }
        }

        self.scheduledTask = task
        let deadline = DispatchTime.now() + self.wordInterval
        print("[AnimatedParagraphView] Scheduling next word in \(wordInterval) seconds.")
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: task)
    }

    private func sendFeedbackForWord(_ word: String) {
//        print("[AnimatedParagraphView] Sending feedback for word: \(word) (thought_id: \(thoughtId), chapter_number: \(chapterNumber))")
        let feedbackData: [String: Any] = [
            "thought_id": thoughtId,
            "chapter_number": chapterNumber,
            "word": word,
            "value": 0.8
        ]
        socketViewModel.sendMessage(action: "feedback", data: feedbackData)
    }

    private func measureWords(paragraph: String, font: UIFont, lineSpacing: CGFloat, width: CGFloat, completion: @escaping ([CGRect]) -> Void) {
        print("[AnimatedParagraphView] measureWords called for paragraph with \(paragraph.components(separatedBy: " ").count) words.")
        let wordsArray = paragraph.components(separatedBy: " ")

        let textStorage = NSTextStorage(string: paragraph)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: paragraph.utf16.count))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraph.utf16.count))

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

        print("[AnimatedParagraphView] measureWords completed.")
        completion(frames)
    }

    private func boundingRect(for range: NSRange, layoutManager: NSLayoutManager, textContainer: NSTextContainer) -> CGRect? {
        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return boundingRect.isEmpty ? nil : boundingRect
    }
}
