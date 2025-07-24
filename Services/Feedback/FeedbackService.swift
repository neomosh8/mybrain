import Foundation
import Combine

class FeedbackService: FeedbackServiceProtocol {
    
    // MARK: - Singleton
    static let shared = FeedbackService()
        
    // MARK: - Private Properties
    private let webSocketService: WebSocketAPI
    private let bluetoothService: MockBluetoothService
    
    // MARK: - Initialization
    private init(
        webSocketService: WebSocketAPI = NetworkServiceManager.shared.webSocket,
        bluetoothService: MockBluetoothService = MockBluetoothService.shared
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
}

