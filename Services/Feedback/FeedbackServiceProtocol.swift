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

// MARK: - FeedbackServiceProtocol

protocol FeedbackServiceProtocol: ObservableObject {
    func submitFeedback(
        thoughtId: String,
        chapterNumber: Int,
        word: String
    ) async -> Result<FeedbackResponse, FeedbackError>
    
    func submitBatchFeedback(
        thoughtId: String,
        chapterNumber: Int,
        words: [String]
    ) async -> Result<FeedbackResponse, FeedbackError>
}
