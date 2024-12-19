import SwiftUI
import Combine

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel

    // Paragraphs will be filled as chapters arrive from the server
    @State private var paragraphs: [String] = []

    @State private var displayedParagraphsCount = 0
    @State private var scrollProxy: ScrollViewProxy?

    // State for adjustable word display speed
    @State private var wordInterval: Double = 0.15

    // State for slider position (floating)
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200) // initial position

    var body: some View {
        ZStack {
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(spacing: 40) {
                        ForEach(0..<displayedParagraphsCount, id: \.self) { index in
                            AnimatedParagraphView(
                                paragraph: paragraphs[index],
                                backgroundColor: Color.blue.opacity(0.2), // change as you like
                                wordInterval: wordInterval
                            ) {
                                // Once a paragraph finishes, request next chapter if available
                                requestNextChapter()
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical)
                    .padding(.horizontal, 16)
                    .onAppear {
                        self.scrollProxy = proxy
                    }
                }
            }

            // Floating movable slider container
            sliderContainer
                .position(sliderPosition)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.sliderPosition = value.location
                        }
                )
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // On appear, request the first chapter
            requestNextChapter()
        }
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapterData = chapterData else { return }
            // Append the received chapter content to paragraphs
            paragraphs.append(chapterData.content)
            // Increase displayedParagraphsCount to show the new paragraph
            withAnimation {
                displayedParagraphsCount = paragraphs.count
            }
        }
    }

    private var sliderContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 200)
                .shadow(radius: 5)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack {
                Image(systemName: "tortoise")
                    .font(.caption)
                    .offset(y: -5)

                Slider(value: $wordInterval, in: 0.05...0.5)
                    .frame(height: 120)      // set width pre-rotation
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x:0.5,y: 0.5)    // adjust if needed
                    .clipped()              // clip if track still overflows

                Image(systemName: "hare")
                    .font(.caption)
                    .offset(y: 5)
            }
            .padding(.vertical, 1) // Add padding if track touches edges
        }
    }

    private func requestNextChapter() {
        // Send next_chapter action if we need a new chapter
        // In this logic, we request whenever we finish displaying the current paragraph.
        // If the server sends chapters continuously, this will continue until no more chapters.
        let messageData: [String: Any] = [
            "thought_id": thought.id,
            "generate_audio": false
        ]
        socketViewModel.sendMessage(action: "next_chapter", data: messageData)
    }
}

struct AnimatedParagraphView: View {
    let paragraph: String
    let backgroundColor: Color
    var wordInterval: Double
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
            // cancel and reschedule with the updated interval for immediate effect.
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

        // Schedule next word
        scheduleNextWord()
    }

    private func scheduleNextWord() {
        guard shownWordsCount < words.count else {
            // All words revealed for this paragraph, trigger onFinished
            onFinished()
            return
        }

        let task = DispatchWorkItem {
            // Reveal next word
            if shownWordsCount < words.count {
                withAnimation {
                    shownWordsCount += 1
                }
                // Schedule next again
                scheduleNextWord()
            } else {
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
