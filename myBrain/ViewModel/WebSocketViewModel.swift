import Foundation
import Combine

class WebSocketViewModel: ObservableObject {
    @Published var welcomeMessage: String?
    @Published var chapterData: ChapterData?
    @Published var incomingMessage: [String: Any]? // New published property for generic JSON messages
    
    // Make these internal so other modules within the app target can access it.
    let baseUrl: String //Make internal
    var cancellables = Set<AnyCancellable>() // Make internal
    
    
    private var webSocketTask: URLSessionWebSocketTask?
    
    private let token: String
    
    init(baseUrl: String, token: String) {
        self.baseUrl = baseUrl
        self.token = token
        connect()
    }
    
    func clearChapterData() {
        DispatchQueue.main.async {
            self.chapterData = nil
        }
    }
    
    private func connect() {
        guard let url = URL(string: "ws://\(baseUrl)/thoughts/") else {
            print("Invalid URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Asia/Tehran", forHTTPHeaderField: "User-Timezone")
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error.localizedDescription)")
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
            }
            
            self.receiveMessage()
        }
    }
    
    
    private func handleIncomingMessage(_ text: String) {
        print("Incoming raw message: \(text)")
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let status = jsonObject["status"] as? String
                if status == "error" {
                    let errorMsg = jsonObject["message"] as? String ?? "Unknown error"
                    print("Connection error: \(errorMsg)")
                    return
                }
                
                guard let type = jsonObject["type"] as? String else {
                    print("No type field found in message.")
                    return
                }
                
                let dataPayload = jsonObject["data"] as? [String: Any]
                
                // Publish the entire JSON message for other views to use
                DispatchQueue.main.async {
                    self.incomingMessage = jsonObject
                }
                
                switch type {
                case "connection_response":
                    handleConnectionResponse(jsonObject)
                case "thoughts_list":
                    handleThoughtsList(dataPayload)
                case "chapter_response":
                    handleChapterResponse(dataPayload)
                case "feedback_response":
                    // Just ignore or handle quietly
                    // No error, no print needed
                    break
                case "thought_update":
                    // Just ignore , since we already publish it to incomingMessage
                    break
                default:
                    print("Unhandled message type: \(type)")
                    break;
                    
                }
            }
        } catch {
            print("Failed to decode incoming message: \(error)")
        }
    }
    
    private func handleConnectionResponse(_ jsonObject: [String: Any]) {
        let status = jsonObject["status"] as? String
        let message = jsonObject["message"] as? String
        
        if status == "success", let welcome = message {
            print("Welcome message: \(welcome)")
            DispatchQueue.main.async {
                self.welcomeMessage = welcome
            }
        } else {
            let fallbackMsg = message ?? "No message"
            print("Received connection_response with unknown status. Message: \(fallbackMsg)")
        }
    }
    
    private func handleThoughtsList(_ dataPayload: [String: Any]?) {
        guard let dataPayload = dataPayload,
              let thoughts = dataPayload["thoughts"] as? [[String: Any]] else {
            print("No thoughts data found.")
            return
        }
        
        print("Received \(thoughts.count) thoughts:")
        //        for thought in thoughts {
        //            if let id = thought["id"], let name = thought["name"] {
        //                print("Thought ID: \(id), Name: \(name)")
        //            }
        //        }
    }
    
    private func handleChapterResponse(_ dataPayload: [String: Any]?) {
        guard let dataPayload = dataPayload else {
            print("No chapter data found.")
            return
        }
        
        // Extract chapter info
        let chapterNumber = dataPayload["chapter_number"] as? Int ?? 0
        let title = dataPayload["title"] as? String ?? "No title"
        let content = dataPayload["content"] as? String ?? "No content"
        let status = dataPayload["status"] as? String ?? "unknown"
        let complete = dataPayload["complete"] as? Bool ?? false  // <-- parse
        
        let chapter = ChapterData(
            chapterNumber: chapterNumber,
            title: title,
            content: content,
            status: status,
            complete: complete  // <-- store
        )
        
        DispatchQueue.main.async {
            self.chapterData = chapter
        }
    }
    
    
    func sendFeedbackWithBiometricData(thoughtId: Int, chapterNumber: Int, word: String, bluetoothService: BluetoothService) {
        let value = bluetoothService.processFeedback(word: word)
        
        let feedbackData: [String: Any] = [
            "thought_id": thoughtId,
            "chapter_number": chapterNumber,
            "word": word,
            "value": value
        ]
        
        self.sendMessage(action: "feedback", data: feedbackData)
    }
    
    
    func sendMessage(action: String, data: [String: Any]) {
        let message: [String: Any] = [
            "action": action,
            "data": data
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                //                print("Sending message: \(jsonString)")
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("Failed to send message: \(error)")
                    }
                }
            }
        } catch {
            print("Failed to encode message: \(error)")
        }
    }
    
    
    func configureForBackgroundOperation() {
        // Keep WebSockets alive in background
        let urlSessionConfig = URLSessionConfiguration.default
        urlSessionConfig.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfig.waitsForConnectivity = true
        
        let pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            // Send a ping to keep connection alive
            self?.sendPing()
        }
        
        // Store timer in cancellables for lifecycle management
        pingTimer.tolerance = 5.0
        cancellables.insert(AnyCancellable {
            pingTimer.invalidate()
        })
    }
    
    private func sendPing() {
        guard let webSocketTask = webSocketTask else { return }
        webSocketTask.sendPing { error in
            if let error = error {
                print("WebSocket ping error: \(error.localizedDescription)")
            }
        }
    }
}

