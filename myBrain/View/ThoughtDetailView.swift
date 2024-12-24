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

    // Flags to handle final chapter
    @State private var hasCompletedAllChapters = false
    @State private var lastChapterComplete = false

    var body: some View {
        ZStack {
            // E-ink background
            Color("EInkBackground")
                .ignoresSafeArea()

            if hasCompletedAllChapters {
                // Once we confirm the final animation has finished,
                // show the completion screen
                ChapterCompletionView(socketViewModel: socketViewModel,
                                      thoughtId: thought.id)

            } else {
                // Show progress if no paragraphs yet
                if displayedParagraphsCount == 0 {
                    ProgressView("Loading First Chapter...")
                        .tint(.gray)
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
                                            // Once this chapter’s animation finishes
                                            let nextIndex = index + 1
                                            // If there's a next paragraph, move forward
                                            if displayedParagraphsCount > nextIndex {
                                                currentChapterIndex = nextIndex
                                            } else {
                                                // No more paragraphs in memory
                                                // If the server indicated "no more chapters," show completion
                                                if lastChapterComplete {
                                                    hasCompletedAllChapters = true
                                                }
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
                    // The speed slider
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
        // Observe when new chapter data arrives
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapterData = chapterData else { return }

            if chapterData.complete {
                // The server indicated "no more chapters"
                lastChapterComplete = true

                // If the server provided final text, optionally show it:
                // (If you want a "final chapter" to read, append it here)
                if !chapterData.content.isEmpty && chapterData.content != "No content" {
                    paragraphs.append(Paragraph(chapterNumber: chapterData.chapterNumber,
                                                content: chapterData.content))
                    displayedParagraphsCount = paragraphs.count
                    if displayedParagraphsCount == 1 {
                        currentChapterIndex = 0
                    }
                }

            } else {
                // Normal chapter
                paragraphs.append(Paragraph(
                    chapterNumber: chapterData.chapterNumber,
                    content: chapterData.content
                ))
                displayedParagraphsCount = paragraphs.count

                // If this is the first chapter
                if displayedParagraphsCount == 1 {
                    currentChapterIndex = 0
                }
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
