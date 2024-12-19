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

    @State private var wordInterval: Double = 0.15
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200) // initial position

    var body: some View {
        ZStack {
            if paragraphs.isEmpty {
                // No chapters loaded yet, show a loading indicator
                ProgressView("Loading First Chapter...")
                    .tint(.white)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            } else {
                // Once we have at least one chapter to display
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 40) {
                            ForEach(0..<displayedParagraphsCount, id: \.self) { index in
                                AnimatedParagraphView(
                                    paragraph: paragraphs[index].content,
                                    backgroundColor: Color.blue.opacity(0.2),
                                    wordInterval: wordInterval,
                                    chapterIndex: index,
                                    thoughtId: thought.id,
                                    chapterNumber: paragraphs[index].chapterNumber,
                                    socketViewModel: socketViewModel,
                                    onHalfway: {
                                        // For subsequent chapters (index > 0), request next chapter at halfway
                                        if index >= 0 {
                                            requestNextChapter()
                                        }
                                    },
                                    onFinished: {
                                        // OnFinished no longer triggers next chapter because we do it at halfway.
                                    }
                                )
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
            // Request the first chapter immediately
            requestNextChapter()
        }
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapterData = chapterData else { return }
            // Append the received chapter content along with its chapterNumber
            paragraphs.append(Paragraph(chapterNumber: chapterData.chapterNumber, content: chapterData.content))
            // Show the new paragraph
            displayedParagraphsCount = paragraphs.count
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
                    .frame(height: 120)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x:0.5,y: 0.5)
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
