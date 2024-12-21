import SwiftUI
import Combine

struct Paragraph {
    let chapterNumber: Int
    let content: String
}

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel

    @State private var paragraphs: [Paragraph] = []
    @State private var displayedParagraphsCount = 0
    @State private var scrollProxy: ScrollViewProxy?
    
    @State private var currentChapterIndex: Int?

    @State private var wordInterval: Double = 0.15
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200)

    var body: some View {
        ZStack {
            // E-ink background throughout:
            Color("EInkBackground")
                .ignoresSafeArea()

            if displayedParagraphsCount == 0 {
                ProgressView("Loading First Chapter...")
                    .tint(.gray)         // Tortoise/hare color
                    .foregroundColor(.black)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 1) {
                            ForEach(0..<displayedParagraphsCount, id: \.self) { index in
                                // Use a softer background in each paragraph
                                AnimatedParagraphView(
                                    paragraph: paragraphs[index].content,
                                    backgroundColor: Color("ParagraphBackground"),
                                    wordInterval: wordInterval,
                                    chapterIndex: index,
                                    thoughtId: thought.id,
                                    chapterNumber: paragraphs[index].chapterNumber,
                                    socketViewModel: socketViewModel,
                                    onHalfway: {
                                        // Request next chapter at halfway
                                        if index >= 0 {
                                            requestNextChapter()
                                        }
                                    },
                                    onFinished: {
                                        // OnFinished no longer triggers next chapter
                                        if displayedParagraphsCount > index + 1 {
                                            currentChapterIndex = index + 1
                                        }
                                    },
                                    currentChapterIndex: $currentChapterIndex
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .onAppear {
                            self.scrollProxy = proxy
                        }
                    }
                }
                sliderContainer
                    .position(sliderPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.sliderPosition = value.location
                            }
                    )
            }
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Request the first chapter
            requestNextChapter()
        }
        .onDisappear {
            // Cancel ongoing processes
            socketViewModel.clearChapterData()
            paragraphs = []
            displayedParagraphsCount = 0
            currentChapterIndex = nil
        }
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapterData = chapterData else { return }
            paragraphs.append(Paragraph(chapterNumber: chapterData.chapterNumber, content: chapterData.content))
            displayedParagraphsCount = paragraphs.count

            if displayedParagraphsCount == 1 {
                currentChapterIndex = 0
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

                Slider(value: $wordInterval, in: 0.01...0.25)
                    .frame(height: 120)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: 0.5, y: 0.5)
                    .clipped()

                Image(systemName: "hare")
                    .font(.caption)
                    .offset(y: 5)
            }
            .padding(.vertical, 1)
        }
    }

    private func requestNextChapter() {
        let messageData: [String: Any] = [
            "thought_id": thought.id,
            "generate_audio": false
        ]
        socketViewModel.sendMessage(action: "next_chapter", data: messageData)
    }
}
