import Foundation
import Combine

class FeedbackService: FeedbackServiceProtocol {
    
    // MARK: - Singleton
    static let shared = FeedbackService()
        
    // MARK: - Private Properties
    private let webSocketService: WebSocketAPI
    private let bluetoothService: BTService
    
    // MARK: - Initialization
    private init(
        webSocketService: WebSocketAPI = NetworkServiceManager.shared.webSocket,
        bluetoothService: BTService = BTService.shared
    ) {
        self.webSocketService = webSocketService
        self.bluetoothService = bluetoothService
    }
    
    // MARK: - FeedbackServiceProtocol Implementation
    
    func submitFeedback(
        thoughtId: String,
        chapterNumber: Int,
        word: String
    ) async -> Result<FeedbackResponse, FeedbackError> {
        
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else {
            return .failure(.invalidWord)
        }
        
        let feedbackValue = bluetoothService.processFeedback(word: cleanWord)

        guard webSocketService.isConnected else {
            return .failure(.webSocketNotConnected)
        }
        
        webSocketService.sendFeedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: cleanWord,
            value: feedbackValue
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
        words: [String]
    ) async -> Result<FeedbackResponse, FeedbackError> {
        
        let cleanWords = words.compactMap { word in
            let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        
        guard !cleanWords.isEmpty else {
            return .failure(.invalidWord)
        }
        
        let feedbacks = cleanWords.map { word in
            let feedbackValue = bluetoothService.processFeedback(word: word)
            return (word: word, value: feedbackValue)
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
            word: cleanWords.first
        ))
    }

}

