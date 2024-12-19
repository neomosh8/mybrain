import Foundation
import Combine

class WebSocketViewModel: ObservableObject {
    @Published var welcomeMessage: String?  // Published property to hold the welcome message

    private var webSocketTask: URLSessionWebSocketTask?
    private let baseUrl: String
    private let token: String

    // If you need to store cancellables for Combine-based streams, you can use this:
    private var cancellables = Set<AnyCancellable>()

    init(baseUrl: String, token: String) {
        self.baseUrl = baseUrl
        self.token = token
        connect()
    }

    /// Establishes the WebSocket connection using the provided baseUrl and token.
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

        // Start listening for messages.
        receiveMessage()
    }

    /// Begins receiving messages from the WebSocket.
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

            // Continuously listen for next messages
            self.receiveMessage()
        }
    }

    /// Handles incoming messages by parsing the JSON and acting on the 'connection_response' event.
    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let type = jsonObject["type"] as? String, type == "connection_response" {

                let status = jsonObject["status"] as? String
                let message = jsonObject["message"] as? String

                if status == "success", let welcome = message {
                    // On successful connection, print and store the welcome message
                    print("Welcome message: \(welcome)")
                    DispatchQueue.main.async {
                        self.welcomeMessage = welcome
                    }
                } else if status == "error", let errorMsg = message {
                    print("Connection error: \(errorMsg)")
                }
            }
        } catch {
            print("Failed to decode incoming message: \(error)")
        }
    }

    /// Sends a message using the predefined format:
    /// {
    ///     "action": "<action_name>",
    ///     "data": { /* action-specific payload */ }
    /// }
    func sendMessage(action: String, data: [String: Any]) {
        let message: [String: Any] = [
            "action": action,
            "data": data
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
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

    /// Closes the WebSocket connection gracefully.
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}
