import Foundation

struct FeedbackItem {
    let word: String
    let value: Double
    let timestamp: Date
    let thoughtId: String
    let chapterNumber: Int
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

struct FeedbackResponse {
    let success: Bool
    let message: String
    let thoughtId: String?
    let chapterNumber: Int?
    let word: String?
}
