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
    
    func requestStreamingLinks(thoughtId: String) {
        let message = WebSocketMessage.streamingLinks(thoughtId: thoughtId)
        sendMessage(message)
    }
    
    func requestListThoughts() {
        let message = WebSocketMessage.listThoughts
        sendMessage(message)
    }
    
    func requestNextChapter(thoughtId: String, generateAudio: Bool) {
        let message = WebSocketMessage.nextChapter(thoughtId: thoughtId, generateAudio: generateAudio)
        sendMessage(message)
    }
    
    func sendFeedback(thoughtId: String, chapterNumber: Int, word: String, value: Double) {
        let message = WebSocketMessage.feedback(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: word,
            value: value
        )
        sendMessage(message)
    }
    
    func requestThoughtChapters(thoughtId: String) {
        let message = WebSocketMessage.thoughtChapters(thoughtId: thoughtId)
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
            openSocket()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendMessage(message)
            }
            return
        }
        
        do {
            let messageDict = message.toDictionary()
            let jsonData = try JSONSerialization.data(withJSONObject: messageDict)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            let task = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask.send(task) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Failed to serialize WebSocket message: \(error)")
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Failed to parse WebSocket message JSON")
            return
        }
        
        guard let messageType = json["type"] as? String,
              let status = json["status"] as? String,
              let message = json["message"] as? String,
              let messageData = json["data"] as? [String: Any] else {
            print("Invalid WebSocket message format: \(json)")
            return
        }
        
        print("Received WebSocket message - Type: \(messageType), Status: \(status), Message: \(message)")
        
        let webSocketMessage: WebSocketMessage
        
        switch messageType {
        case "connection_response":
            webSocketMessage = .response(action: "connection", data: messageData)
        case "thoughts_list":
            webSocketMessage = .response(action: "list_thoughts", data: messageData)
        case "next_chapter_response":
            webSocketMessage = .response(action: "next_chapter", data: messageData)
        case "streaming_links_response":
            webSocketMessage = .response(action: "streaming_links", data: messageData)
        case "thought_chapters_response":
            webSocketMessage = .response(action: "thought_chapters", data: messageData)
        case "thought_update":
            webSocketMessage = .response(action: "thought_update", data: messageData)
        case "error":
            webSocketMessage = .response(action: "error", data: [
                "status": status,
                "message": message,
                "details": messageData
            ])
        default:
            webSocketMessage = .response(action: messageType, data: messageData)
        }
        
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
