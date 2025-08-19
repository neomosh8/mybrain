import Combine

class FeedbackService {
    // MARK: - Singleton
    static let shared = FeedbackService()
    
    // MARK: - Private Properties
    private let webSocketService: WebSocketAPI
    
    // MARK: - Initialization
    private init(
        webSocketService: WebSocketAPI = NetworkServiceManager.shared.webSocket,
    ) {
        self.webSocketService = webSocketService
    }
    
    // MARK: - FeedbackService Implementation
    
    func submitFeedback(
        thoughtId: String,
        chapterNumber: Int,
        word: String,
        value: Double
    ) async -> Result<FeedbackResponse, FeedbackError> {
        
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else {
            return .failure(.invalidWord)
        }
        
        guard webSocketService.isConnected else {
            return .failure(.webSocketNotConnected)
        }
        
        webSocketService.sendFeedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: cleanWord,
            value: value
        )
        
        return .success(FeedbackResponse(
            success: true,
            message: "Feedback sent",
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: cleanWord
        ))
    }
    
    func submitBatchFeedback(
        thoughtId: String,
        chapterNumber: Int,
        feedbacks: [(word: String, value: Double)]
    ) async -> Result<FeedbackResponse, FeedbackError> {
        
        guard !feedbacks.isEmpty else {
            return .failure(.invalidWord)
        }
        
        guard webSocketService.isConnected else {
            return .failure(.webSocketNotConnected)
        }
        
        webSocketService.sendBatchFeedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            feedbacks: feedbacks
        )
        
        return .success(FeedbackResponse(
            success: true,
            message: "Batch feedback sent",
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: feedbacks.first?.word
        ))
    }
}
