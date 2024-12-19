import Foundation
import Combine

class WebSocketViewModel: ObservableObject {
    @Published var welcomeMessage: String?
    @Published var chapterData: ChapterData? // New published property for chapter data

    private var webSocketTask: URLSessionWebSocketTask?
    private let baseUrl: String
    private let token: String
    private var cancellables = Set<AnyCancellable>()

    init(baseUrl: String, token: String) {
        self.baseUrl = baseUrl
        self.token = token
        connect()
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

                switch type {
                case "connection_response":
                    handleConnectionResponse(jsonObject)
                case "thoughts_list":
                    handleThoughtsList(dataPayload)
                case "chapter_response":
                    handleChapterResponse(dataPayload)
                default:
                    print("Unhandled message type: \(type)")
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

        let chapter = ChapterData(chapterNumber: chapterNumber, title: title, content: content, status: status)
        DispatchQueue.main.async {
            self.chapterData = chapter
        }
    }

    func sendMessage(action: String, data: [String: Any]) {
        let message: [String: Any] = [
            "action": action,
            "data": data
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Sending message: \(jsonString)")
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

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

// Simple model to store chapter data
struct ChapterData {
    let chapterNumber: Int
    let title: String
    let content: String
    let status: String
}
