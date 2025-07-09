import SwiftUI
import Combine

struct Paragraph {
    let chapterNumber: Int
    let content: String
}

struct ThoughtDetailView: View {
    let thought: Thought
    private let networkService = NetworkServiceManager.shared
    
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
    
    // Loading state
    @State private var isLoadingChapter = false
    
    // Cancellables for subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        // Wrap in ThoughtNavigationView for resume/restart functionality
        ThoughtNavigationView(thought: thought) {
            AnyView(mainReadingContent)
        }
        .onResume {
            requestNextChapter()
        }
        .onResetFinished {
            resetLocalReadingState()
            requestNextChapter()
        }
        .onAppear {
            setupWebSocketSubscriptions()
            // Request the first chapter
            requestNextChapter()
        }
        .onDisappear {
            cancellables.removeAll()
        }
    }
    
    // MARK: - Main Reading Content
    private var mainReadingContent: some View {
        ZStack {
            Color("EInkBackground").ignoresSafeArea()
            
            if hasCompletedAllChapters {
                ChapterCompletionView(thoughtId: thought.id)
            } else if displayedParagraphsCount == 0 {
                loadingView
            } else {
                readingInterface
            }
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            if isLoadingChapter {
                ProgressView("Loading Chapter...")
                    .tint(.gray)
                    .foregroundColor(.black)
            } else {
                Button("Load Content") {
                    requestNextChapter()
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
        VStack(spacing: 0) {
            // Main reading area
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
                            onHalfway: {
                                // Auto-fetch next chapter at halfway point
                                requestNextChapter()
                            },
                            onFinished: {
                                onParagraphFinished(index)
                            },
                            currentChapterIndex: $currentChapterIndex
                        )
                    }
                    
                    // Loading indicator for next chapter
                    if isLoadingChapter && displayedParagraphsCount > 0 {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading next chapter...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 16)
            }
            
            // Speed Slider
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
    
    // MARK: - WebSocket Methods
    
    private func requestNextChapter() {
        guard !isLoadingChapter else { return }
        
        isLoadingChapter = true
        
        // Send WebSocket request for next chapter
        networkService.webSocket.sendNextChapter(thoughtId: thought.id, generateAudio: false)
    }
    
    private func setupWebSocketSubscriptions() {
        // Subscribe to WebSocket messages for chapter responses
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { message in
                switch message {
                case .response(let action, let data):
                    if action == "chapter_response" {
                        self.handleChapterResponse(data)
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Response Handler
    
    private func handleChapterResponse(_ data: [String: Any]) {
        isLoadingChapter = false
        
        guard let chapterNumber = data["chapter_number"] as? Int,
              let content = data["content"] as? String else {
            print("Invalid chapter response data")
            return
        }
        
        let isComplete = data["complete"] as? Bool ?? false
        
        if isComplete {
            // Server says no more chapters
            lastChapterComplete = true
            
            // Optionally append final content if it's meaningful
            if !content.isEmpty && content != "No content" {
                let newParagraph = Paragraph(chapterNumber: chapterNumber, content: content)
                
                // Check if we already have this chapter
                if !paragraphs.contains(where: { $0.chapterNumber == chapterNumber }) {
                    paragraphs.append(newParagraph)
                    displayedParagraphsCount = paragraphs.count
                    
                    if displayedParagraphsCount == 1 {
                        currentChapterIndex = 0
                    }
                }
            }
        } else {
            // Normal chapter
            let newParagraph = Paragraph(chapterNumber: chapterNumber, content: content)
            
            // Check if we already have this chapter
            if !paragraphs.contains(where: { $0.chapterNumber == chapterNumber }) {
                paragraphs.append(newParagraph)
                displayedParagraphsCount = paragraphs.count
                
                // If this is the first paragraph
                if displayedParagraphsCount == 1 {
                    currentChapterIndex = 0
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func onParagraphFinished(_ index: Int) {
        let nextIndex = index + 1
        if nextIndex < displayedParagraphsCount {
            currentChapterIndex = nextIndex
        } else {
            if lastChapterComplete {
                hasCompletedAllChapters = true
            } else {
                // Request next chapter when current finishes
                requestNextChapter()
            }
        }
    }
    
    private func resetLocalReadingState() {
        paragraphs.removeAll()
        displayedParagraphsCount = 0
        currentChapterIndex = nil
        hasCompletedAllChapters = false
        lastChapterComplete = false
        isLoadingChapter = false
    }
}
