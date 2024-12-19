import SwiftUI
import Combine

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel

    @State private var paragraphs: [String] = []
    @State private var displayedParagraphsCount = 0
    @State private var scrollProxy: ScrollViewProxy?

    // State for adjustable word display speed
    @State private var wordInterval: Double = 0.15

    // State for slider position (floating)
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200) // initial position

    var body: some View {
        ZStack {
            if displayedParagraphsCount == 0 {
                // No chapters loaded yet, show a loading indicator
                ProgressView("Loading First Chapter...")
                    .tint(.white)
                    .foregroundColor(.white)
                    .font(.headline)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            } else {
                // Once we have at least one chapter to display
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 40) {
                            ForEach(0..<displayedParagraphsCount, id: \.self) { index in
                                AnimatedParagraphView(
                                    paragraph: paragraphs[index],
                                    backgroundColor: Color.blue.opacity(0.2),
                                    wordInterval: wordInterval,
                                    chapterIndex: index,
                                    onHalfway: {
                                        // For subsequent chapters (index > 0), request next chapter at halfway
                                        if index > 0 {
                                            requestNextChapter()
                                        }
                                    },
                                    onFinished: {
                                        // OnFinished no longer triggers next chapter
                                        // because we request it at halfway instead.
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
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Request the first chapter immediately
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
