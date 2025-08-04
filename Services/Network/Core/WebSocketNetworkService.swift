import Foundation
import Combine

final class WebSocketNetworkService: WebSocketAPI {
    private let baseURL: String
    private let tokenStorage: TokenStorage
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var pingTimer: Timer?
    
    // Publishers
    private let connectionStateSubject = PassthroughSubject<WebSocketConnectionState, Never>()
    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    var messages: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    
    var isConnected: Bool {
        webSocketTask?.state == .running
    }
    
    init(baseURL: String, tokenStorage: TokenStorage) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        
        let config = URLSessionConfiguration.default
        config.shouldUseExtendedBackgroundIdleMode = true
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func openSocket() {
        closeSocket()
        
        connectionStateSubject.send(.connecting)
        
        guard let url = URL(string: "\(baseURL)/thoughts/") else {
            connectionStateSubject.send(.failed(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        if let token = tokenStorage.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(NetworkConstants.userTimezone, forHTTPHeaderField: "User-Timezone")
        
        webSocketTask = session.webSocketTask(with: request)
        startReceiving()
        webSocketTask?.resume()
        
        connectionStateSubject.send(.connected)
        setupPingTimer()
    }
    
    func closeSocket() {
        pingTimer?.invalidate()
        pingTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionStateSubject.send(.disconnected)
    }
    
    func requestStreamingLinks(thoughtId: String) {
        let action = WebSocketAction.streamingLinks(thoughtId: thoughtId)
        sendAction(action)
    }

    func requestNextChapter(thoughtId: String, generateAudio: Bool) {
        let action = WebSocketAction.nextChapter(thoughtId: thoughtId, generateAudio: generateAudio)
        sendAction(action)
    }

    func sendFeedback(thoughtId: String, chapterNumber: Int, word: String, value: Double) {
        let action = WebSocketAction.feedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: word,
            value: value
        )
        sendAction(action)
    }
    
    func sendBatchFeedback(thoughtId: String, chapterNumber: Int, feedbacks: [(word: String, value: Double)]) {
        let action = WebSocketAction.batchFeedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            feedbacks: feedbacks
        )
        sendAction(action)
    }
    
    func requestThoughtStatus(thoughtId: String) {
        let action = WebSocketAction.thoughtStatus(thoughtId: thoughtId)
        sendAction(action)
    }
    
    func activateReceiveMessage(callback: @escaping (WebSocketMessage) -> Void) {
        messages.sink { message in
            callback(message)
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func sendAction(_ action: WebSocketAction) {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            print("WebSocket not connected. Action dropped: \(action)")
            return
        }
        
        do {
            let actionDict = action.toDictionary()
            let jsonData = try JSONSerialization.data(withJSONObject: actionDict)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    
            let task = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask.send(task) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Failed to serialize WebSocket action: \(error)")
        }
    }
    
    private func startReceiving() {
        Task { [weak self] in
            await self?.receiveMessages()
        }
    }
    
    private func receiveMessages() async {
        while let webSocketTask = webSocketTask, webSocketTask.state == .running {
            do {
                let message = try await webSocketTask.receive()
                await MainActor.run {
                    switch message {
                    case .string(let text):
                        self.handleIncomingMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingMessage(text)
                        }
                    @unknown default:
                        break
                    }
                }
            } catch {
                print("WebSocket receive error: \(error)")
                await MainActor.run {
                    self.connectionStateSubject.send(.failed(error))
                }
                break
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {       
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse WebSocket message JSON")
            return
        }
        
        guard let messageType = json["type"] as? String,
              let status = json["status"] as? String,
              let message = json["message"] as? String else {
            print("Invalid WebSocket message format: \(json)")
            return
        }
        
        let messageData = json["data"] as? [String: Any]
        
        let webSocketMessage = WebSocketMessage(
            type: messageType,
            status: status,
            message: message,
            data: messageData
        )
        
        messageSubject.send(webSocketMessage)
    }
    
    private func setupPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("WebSocket ping error: \(error)")
                self?.connectionStateSubject.send(.failed(error))
            }
        }
    }
}
