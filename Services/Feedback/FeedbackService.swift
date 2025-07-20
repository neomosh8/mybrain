import Foundation
import Combine

class FeedbackService: FeedbackServiceProtocol {
    
    // MARK: - Singleton
    static let shared = FeedbackService()
    
    // MARK: - Published Properties
    @Published private(set) var pendingFeedbackCount: Int = 0
    
    // MARK: - Private Properties
    private let webSocketService: WebSocketAPI
    private let bluetoothService: BluetoothService
    private var cancellables = Set<AnyCancellable>()
    
    private let feedbackResponsesSubject = PassthroughSubject<FeedbackResponse, Never>()
    private var pendingFeedbacks: [FeedbackRequest] = []
    private let feedbackQueue = DispatchQueue(label: "com.neocore.feedback", qos: .utility)
    
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
        
        setupWebSocketListener()
    }
    
    // MARK: - FeedbackServiceProtocol Implementation
    
    func submitFeedback(
        thoughtId: String,
        chapterNumber: Int,
        word: String
    ) async -> Result<FeedbackResponse, FeedbackError> {
        
        return await withCheckedContinuation { continuation in
            submitFeedbackInternal(
                thoughtId: thoughtId,
                chapterNumber: chapterNumber,
                word: word
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func submitFeedbackSync(
        thoughtId: String,
        chapterNumber: Int,
        word: String
    ) {
        submitFeedbackInternal(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: word
        ) { _ in
            // Fire and forget for sync calls
        }
    }
    
    func retryFailedSubmissions() async {
        await withTaskGroup(of: Void.self) { group in
            let feedbacksToRetry = feedbackQueue.sync { pendingFeedbacks }
            
            for feedback in feedbacksToRetry {
                group.addTask {
                    let _ = await self.submitFeedback(
                        thoughtId: feedback.thoughtId,
                        chapterNumber: feedback.chapterNumber,
                        word: feedback.word
                    )
                }
            }
        }
    }
    
    func clearPendingFeedback() {
        feedbackQueue.sync {
            pendingFeedbacks.removeAll()
            updatePendingCount()
        }
    }
    
    // MARK: - Private Methods
    
    private func submitFeedbackInternal(
        thoughtId: String,
        chapterNumber: Int,
        word: String,
        completion: @escaping (Result<FeedbackResponse, FeedbackError>) -> Void
    ) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else {
            completion(.failure(.invalidWord))
            return
        }
        
        // Get feedback value from BluetoothService
        let feedbackValue = bluetoothService.processFeedback(word: cleanWord)
        
        let feedbackRequest = FeedbackRequest(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: cleanWord,
            value: feedbackValue
        )
        
        feedbackQueue.async {
            self.pendingFeedbacks.append(feedbackRequest)
            self.updatePendingCount()
        }
        
        sendFeedbackToServer(feedbackRequest) { [weak self] result in
            switch result {
            case .success(let response):
                self?.feedbackQueue.async {
                    self?.pendingFeedbacks.removeAll { $0.thoughtId == thoughtId && $0.word == cleanWord }
                    self?.updatePendingCount()
                }
                completion(.success(response))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func sendFeedbackToServer(
        _ feedback: FeedbackRequest,
        completion: @escaping (Result<FeedbackResponse, FeedbackError>) -> Void
    ) {
        guard webSocketService.isConnected else {
            completion(.failure(.webSocketNotConnected))
            return
        }
        
        let requestId = "\(feedback.thoughtId)_\(feedback.chapterNumber)_\(feedback.word)_\(feedback.timestamp.timeIntervalSince1970)"
        pendingCompletions[requestId] = completion
        
        webSocketService.sendFeedback(
            thoughtId: feedback.thoughtId,
            chapterNumber: feedback.chapterNumber,
            word: feedback.word,
            value: feedback.value
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if let storedCompletion = self.pendingCompletions.removeValue(forKey: requestId) {
                storedCompletion(.failure(.submissionFailed("Request timeout")))
            }
        }
    }
    
    private var pendingCompletions: [String: (Result<FeedbackResponse, FeedbackError>) -> Void] = [:]
    
    private func setupWebSocketListener() {
        webSocketService.messages
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .feedbackResponse(let status, let messageText, let data):
            let response = FeedbackResponse(
                success: status.isSuccess,
                message: messageText,
                thoughtId: data?["thought_id"] as? String,
                chapterNumber: data?["chapter_number"] as? Int,
                word: data?["word"] as? String
            )
                        
            feedbackResponsesSubject.send(response)
            
            if let thoughtId = response.thoughtId,
               let chapterNumber = response.chapterNumber,
               let word = response.word {
                                
                let exactKey = pendingCompletions.keys.first { key in
                    key.hasPrefix("\(thoughtId)_\(chapterNumber)_\(word)_")
                }
                
                if let key = exactKey,
                   let completion = pendingCompletions.removeValue(forKey: key) {
                    completion(.success(response))
                } else {
                    print("⚠️ No pending completion found")
                }
            }
            
        default:
            break
        }
    }
    
    private func updatePendingCount() {
        DispatchQueue.main.async {
            self.pendingFeedbackCount = self.pendingFeedbacks.count
        }
    }
}

