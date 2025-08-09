import Foundation
import Combine

// MARK: - Feedback Models

struct FeedbackResponse {
    let success: Bool
    let message: String
    let thoughtId: String?
    let chapterNumber: Int?
    let word: String?
}

enum FeedbackError: Error, LocalizedError {
    case invalidWord
    case bluetoothServiceUnavailable
    case webSocketNotConnected
    case submissionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "Invalid word provided for feedback"
        case .bluetoothServiceUnavailable:
            return "Bluetooth service is not available"
        case .webSocketNotConnected:
            return "WebSocket connection is not available"
        case .submissionFailed(let message):
            return "Feedback submission failed: \(message)"
        }
    }
}


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
