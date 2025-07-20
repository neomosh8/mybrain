import Foundation
import Combine

class FeedbackService: FeedbackServiceProtocol {
    
    // MARK: - Singleton
    static let shared = FeedbackService()
        
    // MARK: - Private Properties
    private let webSocketService: WebSocketAPI
    private let bluetoothService: BluetoothService
    
    private let feedbackResponsesSubject = PassthroughSubject<FeedbackResponse, Never>()
    
    private var lastUIUpdate = Date()
    private let uiUpdateInterval: TimeInterval = 2.0

    // MARK: - Public Properties
    var feedbackResponses: AnyPublisher<FeedbackResponse, Never> {
        feedbackResponsesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private init(
        webSocketService: WebSocketAPI = NetworkServiceManager.shared.webSocket,
        bluetoothService: BluetoothService = BluetoothService.shared
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
        
//        let now = Date()
//        if now.timeIntervalSince(lastUIUpdate) > uiUpdateInterval {
//            bluetoothService.updateFeedbackValueForUI(feedbackValue)
//            await MainActor.run {
//                lastUIUpdate = now
//            }
//        }
        
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

