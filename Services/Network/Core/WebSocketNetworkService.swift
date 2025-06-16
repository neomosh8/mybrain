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
        
        // Add required headers
        if let token = tokenStorage.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(NetworkConstants.userTimezone, forHTTPHeaderField: "User-Timezone")
        
        webSocketTask = session.webSocketTask(with: request)
        receiveMessage()
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
    
    func sendStreamingLinks(thoughtId: Int) {
        let message = WebSocketMessage.streamingLinks(thoughtId: thoughtId)
        sendMessage(message)
    }
    
    func sendNextChapter(thoughtId: Int, generateAudio: Bool) {
        let message = WebSocketMessage.nextChapter(thoughtId: thoughtId, generateAudio: generateAudio)
        sendMessage(message)
    }
    
    func sendFeedback(thoughtId: Int, chapterNumber: Int, word: String, value: Double) {
        let message = WebSocketMessage.feedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: word,
            value: value
        )
        sendMessage(message)
    }
    
    func activateReceiveMessage(callback: @escaping (WebSocketMessage) -> Void) {
        messages.sink { message in
            callback(message)
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func sendMessage(_ message: WebSocketMessage) {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            // Auto-reconnect if not connected
            openSocket()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendMessage(message)
            }
            return
        }
        
        do {
            let messageDict = message.toDictionary()
            let data = try JSONSerialization.data(withJSONObject: messageDict)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocketTask.send(.string(jsonString)) { error in
                    if let error = error {
                        print("WebSocket send error: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to encode WebSocket message: \(error)")
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
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
                self.receiveMessage() // Continue receiving
                
            case .failure(let error):
                self.connectionStateSubject.send(.failed(error))
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String,
              let messageData = json["data"] as? [String: Any] else {
            return
        }
        
        let message = WebSocketMessage.response(action: action, data: messageData)
        messageSubject.send(message)
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
