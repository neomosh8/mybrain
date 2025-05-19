import SwiftUI
import Combine

struct Paragraph {
    let chapterNumber: Int
    let content: String
}

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel
    
    // Reading state
    @State private var paragraphs: [Paragraph] = []
    @State private var displayedParagraphsCount = 0
    @State private var currentChapterIndex: Int?
    
    // If final chapter is done
    @State private var hasCompletedAllChapters = false
    @State private var lastChapterComplete = false
    
    // Speed
    @State private var wordInterval: Double = 0.15
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200)
    
    var body: some View {
        // 1) Wrap in our ThoughtNavigationView (always overlay style)
        ThoughtNavigationView(
            thought: thought,
            socketViewModel: socketViewModel
        ) {
            mainReadingContent
        }
        // 2) If user picks “Resume,” just request next chapter
        .onResume {
            requestNextChapter()
        }
        // 3) If user picks “Restart from beginning” and the server confirms,
        // reset everything and fetch the first chapter:
        .onResetFinished {
            resetLocalReadingState()
            requestNextChapter()
        }
        .onDisappear {
            // Cancel any ongoing processes if needed
            socketViewModel.clearChapterData()
        }
        // 4) Observe incoming chapters
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapter = chapterData else { return }
            
            if chapter.complete {
                // Server says no more chapters
                lastChapterComplete = true
                // Optionally append final content
                if !chapter.content.isEmpty && chapter.content != "No content" {
                    paragraphs.append(Paragraph(
                        chapterNumber: chapter.chapterNumber,
                        content: chapter.content
                    ))
                    displayedParagraphsCount = paragraphs.count
                    if displayedParagraphsCount == 1 {
                        currentChapterIndex = 0
                    }
                }
            } else {
                // Normal chapter
                paragraphs.append(
                    Paragraph(chapterNumber: chapter.chapterNumber,
                              content: chapter.content)
                )
                displayedParagraphsCount = paragraphs.count
                
                // If this is the first paragraph
                if displayedParagraphsCount == 1 {
                    currentChapterIndex = 0
                }
            }
        }
    }
    
    // MARK: - Main Reading Content
    private var mainReadingContent: some View {
        ZStack {
            Color("EInkBackground").ignoresSafeArea()
            
            if hasCompletedAllChapters {
                // Show your final completion view
                ChapterCompletionView(socketViewModel: socketViewModel,
                                      thoughtId: thought.id)
                
            } else if displayedParagraphsCount == 0 {
                // No paragraphs yet => loading
                ProgressView("Loading Chapter...")
                    .tint(.gray)
                    .foregroundColor(.black)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                // Normal reading
                ScrollView {
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
                                    // If you want to auto-fetch next chapter at halfway:
                                    requestNextChapter()
                                },
                                onFinished: {
                                    onParagraphFinished(index)
                                },
                                currentChapterIndex: $currentChapterIndex
                            )
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 16)
                }
                
                // The Speed Slider
                speedSlider
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
    }
    
    private func onParagraphFinished(_ index: Int) {
        let nextIndex = index + 1
        if nextIndex < displayedParagraphsCount {
            currentChapterIndex = nextIndex
        } else {
            if lastChapterComplete {
                hasCompletedAllChapters = true
            }
        }
    }
    
    // MARK: - Speed Slider
    private var speedSlider: some View {
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
    
    // MARK: - Helper Methods
    private func requestNextChapter() {
        let data: [String: Any] = [
            "thought_id": thought.id,
            "generate_audio": false
        ]
        socketViewModel.sendMessage(action: "next_chapter", data: data)
    }
    
    private func resetLocalReadingState() {
        paragraphs.removeAll()
        displayedParagraphsCount = 0
        currentChapterIndex = nil
        hasCompletedAllChapters = false
        lastChapterComplete = false
    }
}
