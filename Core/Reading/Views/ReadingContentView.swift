import SwiftUICore
import SwiftUI


struct ReadingContentView: View {
    let thought: Thought
    
    @StateObject private var viewModel = ReadingViewModel()
    
    var body: some View {
        ZStack {
            Color("EInkBackground").ignoresSafeArea()
            
            if viewModel.hasCompletedAllChapters {
                ChapterCompletionView(thoughtId: thought.id)
            } else if viewModel.chapters.isEmpty {
                loadingView
            } else {
                readingInterface
            }
            
            // Reading speed slider
            ReadingSpeedSlider(
                speed: $viewModel.readingSpeed,
                position: $viewModel.sliderPosition
            )
        }
        .onAppear {
            print("👀 ReadingContentView appeared, setting up for thought: \(thought.id)")

            viewModel.setup(for: thought)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            if viewModel.isLoadingChapter {
                ProgressView("Loading Chapter...")
                    .tint(.gray)
                    .foregroundColor(.black)
            } else {
                Button("Load Content") {
                    viewModel.requestNextChapter()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var readingInterface: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(0..<viewModel.displayedChapterCount, id: \.self) { index in
                    AnimatedParagraphView(
                        paragraph: viewModel.chapters[index].content,
                        backgroundColor: Color("ParagraphBackground"),
                        wordInterval: viewModel.readingSpeed,
                        chapterIndex: index,
                        thoughtId: thought.id,
                        chapterNumber: viewModel.chapters[index].number,
                        onHalfway: {
                            viewModel.onChapterHalfway()
                        },
                        onFinished: {
                            viewModel.onChapterFinished(index)
                        },
                        currentChapterIndex: $viewModel.currentChapterIndex
                    )
                }
            }
        }
    }
}
