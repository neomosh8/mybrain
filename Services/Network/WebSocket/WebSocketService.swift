import Foundation
import Combine

class WebSocketManager: WebSocketService, ThoughtWebSocketService {
    // MARK: - Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL: URL
    private let tokenStorage: TokenStorage
    private let session: URLSession
    
    // Publishers
    private let messageSubject = PassthroughSubject<[String: Any], Never>()
    private let connectionStateSubject = PassthroughSubject<WebSocketConnectionState, Never>()
    private let chapterDataSubject = PassthroughSubject<ChapterData?, Never>()
    private let welcomeMessageSubject = PassthroughSubject<String?, Never>()
    
    private let webSocketQueue = DispatchQueue(label: "com.neocore.myBrain.websocket", qos: .userInteractive)
    
    private var pingTimer: Timer?
    
    private(set) var isConnected: Bool = false
    
    var messagePublisher: AnyPublisher<[String: Any], Never> {
        return messageSubject.eraseToAnyPublisher()
    }
    
    var connectionStatePublisher: AnyPublisher<WebSocketConnectionState, Never> {
        return connectionStateSubject.eraseToAnyPublisher()
    }
    
    var chapterDataPublisher: AnyPublisher<ChapterData?, Never> {
        return chapterDataSubject.eraseToAnyPublisher()
    }
    
    var welcomeMessagePublisher: AnyPublisher<String?, Never> {
        return welcomeMessageSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(baseURL: URL, tokenStorage: TokenStorage, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        self.session = session
    }
    
    // MARK: - WebSocketService Implementation
    func connect() {
        disconnect()
        
        connectionStateSubject.send(.connecting)
        
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            connectionStateSubject.send(.failed(NetworkError.invalidURL))
            return
        }
        
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/thoughts/"
        
        guard let url = components.url else {
            connectionStateSubject.send(.failed(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        
        if let accessToken = tokenStorage.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("Asia/Tehran", forHTTPHeaderField: "User-Timezone")
        
        webSocketTask = session.webSocketTask(with: request)
        receiveMessage()
        webSocketTask?.resume()
        
        setupPingTimer()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStateSubject.send(.disconnected)
        
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    func sendMessage(action: String, data: [String: Any]) {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            connect()
            
            webSocketQueue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendMessage(action: action, data: data)
            }
            return
        }
        
        let message: [String: Any] = [
            "action": action,
            "data": data
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                #if DEBUG
                print("Sending WebSocket message: \(jsonString)")
                #endif
                
                webSocketTask.send(.string(jsonString)) { [weak self] error in
                    if let error = error {
                        self?.handleWebSocketError(error)
                    }
                }
            }
        } catch {
            print("Failed to encode WebSocket message: \(error)")
        }
    }
    
    func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.handleWebSocketError(error)
            }
        }
    }
    
    func configureForBackgroundOperation() {
        let urlSessionConfig = URLSessionConfiguration.default
        urlSessionConfig.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfig.waitsForConnectivity = true
    }
    
    // MARK: - ThoughtWebSocketService Implementation
    
    func requestNextChapter(thoughtId: Int, generateAudio: Bool) {
        let data: [String: Any] = [
            "thought_id": thoughtId,
            "generate_audio": generateAudio
        ]
        
        sendMessage(action: "next_chapter", data: data)
    }
    
    func requestThoughtStatus(thoughtId: Int) {
        sendMessage(action: "thought_status", data: ["thought_id": thoughtId])
    }
    
    func requestStreamingLinks(thoughtId: Int) {
        sendMessage(action: "streaming_links", data: ["thought_id": thoughtId])
    }
    
    func sendFeedback(thoughtId: Int, chapterNumber: Int, word: String, value: Double) {
        let feedbackData: [String: Any] = [
            "thought_id": thoughtId,
            "chapter_number": chapterNumber,
            "word": word,
            "value": value
        ]
        
        sendMessage(action: "feedback", data: feedbackData)
    }
    
    func resetReading(thoughtId: Int) {
        sendMessage(action: "reset_reading", data: ["thought_id": thoughtId])
    }
    
    func getFeedbacks(thoughtId: Int) {
        let payload: [String: Any] = ["thought_id": thoughtId]
        sendMessage(action: "get_feedbacks", data: payload)
    }
    
    // MARK: - Private Helper Methods
    
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
                    } else {
                        print("Received non-text data that could not be decoded.")
                    }
                @unknown default:
                    print("Received an unknown message type.")
                }
                
                self.receiveMessage()
                
            case .failure(let error):
                self.handleWebSocketError(error)
                
                self.webSocketQueue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.connect()
                }
            }
        }
    }
    
    private func handleIncomingMessage(_ text: String) {
        #if DEBUG
        print("Received WebSocket message: \(text)")
        #endif
        
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                DispatchQueue.main.async {
                    self.messageSubject.send(jsonObject)
                }
                
                self.processSpecificMessageTypes(jsonObject)
            }
        } catch {
            print("Failed to decode incoming WebSocket message: \(error)")
        }
    }
    
    private func processSpecificMessageTypes(_ jsonObject: [String: Any]) {
        guard let type = jsonObject["type"] as? String else {
            if let status = jsonObject["status"] as? String, status == "error" {
                let errorMsg = jsonObject["message"] as? String ?? "Unknown error"
                print("WebSocket connection error: \(errorMsg)")
                connectionStateSubject.send(.failed(NetworkError.serverError(statusCode: 400, message: errorMsg)))
            }
            return
        }
        
        switch type {
        case "connection_response":
            handleConnectionResponse(jsonObject)
        case "chapter_response":
            handleChapterResponse(jsonObject)
        default:
            break
        }
    }
    
    private func handleConnectionResponse(_ jsonObject: [String: Any]) {
        let status = jsonObject["status"] as? String
        let message = jsonObject["message"] as? String
        
        if status == "success", let welcome = message {
            isConnected = true
            connectionStateSubject.send(.connected)
            
            DispatchQueue.main.async {
                self.welcomeMessageSubject.send(welcome)
            }
        } else {
            let fallbackMsg = message ?? "No message"
            print("Received connection_response with unknown status. Message: \(fallbackMsg)")
        }
    }
    
    private func handleChapterResponse(_ jsonObject: [String: Any]) {
        guard let dataPayload = jsonObject["data"] as? [String: Any] else {
            print("No chapter data found.")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dataPayload, options: [])
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let chapterData = try decoder.decode(ChapterData.self, from: jsonData)
            
            DispatchQueue.main.async {
                self.chapterDataSubject.send(chapterData)
            }
        } catch {
            print("Error parsing chapter data: \(error)")
        }
    }
    
    private func handleWebSocketError(_ error: Error) {
        print("WebSocket error: \(error.localizedDescription)")
        isConnected = false
        connectionStateSubject.send(.failed(error))
    }
    
    private func setupPingTimer() {
        pingTimer?.invalidate()
        
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
}
