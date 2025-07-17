import Foundation
import Combine

@MainActor
class ReadingViewModel: ObservableObject {
    private let networkService = NetworkServiceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Chapter state
    @Published var chapters: [ChapterData] = []
    @Published var displayedChapterCount = 0
    @Published var currentChapterIndex: Int?
    @Published var isPlaying = false
    @Published var hasCompletedAllChapters = false
    @Published var isLastChapter = false
    
    // UI state
    @Published var readingSpeed: Double = 0.15
    @Published var sliderPosition = CGPoint(x: 100, y: 200)
    @Published var isLoadingChapter = false
    
    // Internal state
    private var thoughtId: String = ""
    private var hasRequestedNextChapter = false
    
    func setup(for thought: Thought) {
        self.thoughtId = thought.id
        setupWebSocketSubscriptions()
        requestNextChapter()
    }
    
    func cleanup() {
        cancellables.removeAll()
        networkService.webSocket.closeSocket()
    }
    
    func requestNextChapter() {
        guard !isLoadingChapter else { return }
        
        isLoadingChapter = true
        hasRequestedNextChapter = false
        
        networkService.webSocket.requestNextChapter(
            thoughtId: thoughtId,
            generateAudio: false
        )
    }
    
    func onChapterHalfway() {
        // Only request next chapter once per halfway trigger
        guard !hasRequestedNextChapter else { return }
        hasRequestedNextChapter = true
        requestNextChapter()
    }
    
    func onChapterFinished(_ index: Int) {
        let nextIndex = index + 1
        
        if nextIndex < displayedChapterCount {
            // Move to next chapter
            currentChapterIndex = nextIndex
        } else if isLastChapter {
            // All chapters completed
            hasCompletedAllChapters = true
        }
        // If not last chapter and no next chapter loaded, wait for server response
    }
    
    private func setupWebSocketSubscriptions() {
        networkService.webSocket.messages
            .compactMap { message -> (String, [String: Any])? in
                switch message {
                case .response(let action, let data):
                    return action == "chapter_response" ? (action, data) : nil
                default:
                    return nil
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (action, data) in
                print("📖 Processing chapter response")
                self?.handleChapterResponse(data)
            }
            .store(in: &cancellables)
    }
    
    private func handleChapterResponse(_ data: [String: Any]) {
        print("📖 handleChapterResponse called with data: \(data)")
        
        isLoadingChapter = false
        
        guard let chapterNumber = data["chapter_number"] as? Int,
              let content = data["content"] as? String else {
            print("❌ Invalid chapter response data")
            return
        }
        
        print("📖 Chapter \(chapterNumber) received, content length: \(content.count)")
        
        let isComplete = data["complete"] as? Bool ?? false
        print("📖 Is complete: \(isComplete)")
        
        if isComplete {
            isLastChapter = true
            
            // Add final content if meaningful
            if !content.isEmpty && content != "No content" {
                addChapter(number: chapterNumber, content: content)
            }
        } else {
            addChapter(number: chapterNumber, content: content)
        }
    }
    
    private func addChapter(number: Int, content: String) {
        let newChapter = ChapterData(number: number, content: content)
        
        // Avoid duplicates
        guard !chapters.contains(where: { $0.number == number }) else { return }
        
        chapters.append(newChapter)
        displayedChapterCount = chapters.count
        
        // Start animation on first chapter
        if displayedChapterCount == 1 {
            currentChapterIndex = 0
        }
    }

    func togglePlayback() {
        isPlaying.toggle()
        // Add your pause/resume logic here
    }
    
    deinit {
        cancellables.removeAll()
    }
}
