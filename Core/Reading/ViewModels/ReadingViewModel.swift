import Foundation
import Combine

@MainActor
class ReadingViewModel: ObservableObject {
    private let networkService = NetworkServiceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Chapter state
    @Published var chapters: [ChapterTextResponseData] = []
    @Published var displayedChapterCount = 0
    @Published var currentChapterIndex: Int?
    @Published var isPlaying = false
    @Published var hasCompletedAllChapters = false
    @Published var isLastChapter = false
    
    // UI state
    @Published var readingSpeed: Double = 0.3
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
    
    // MARK: - Updated WebSocket handling in ReadingViewModel

    private func setupWebSocketSubscriptions() {
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }

    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .chapterText(let status, let message, let data):
            if status.isSuccess {
                handleTextChapterResponse(data: data)
            } else {
                isLoadingChapter = false
            }
            
        case .chapterComplete(_, let message, let data):
            if let completeData = ChapterCompleteResponseData(from: data),
               let complete = completeData.complete,
               complete {
                isLastChapter = true
                hasCompletedAllChapters = true
            }
            isLoadingChapter = false

        default:
            break
        }
    }

    private func handleTextChapterResponse(data: [String: Any]?) {
        isLoadingChapter = false
        
        guard let chapterData = ChapterTextResponseData(from: data) else {
            return
        }
                
        addChapter(chapterData: chapterData)
    }
    
    private func addChapter(chapterData: ChapterTextResponseData) {
        guard !chapters.contains(where: { $0.chapterNumber == chapterData.chapterNumber }) else { return }
        
        chapters.append(chapterData)
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
