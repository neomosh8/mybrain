import Foundation
import UIKit
import Combine

class ServerConnect: NetworkService, AuthNetworkService, ThoughtNetworkService, WebSocketService, ThoughtWebSocketService {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let session: URLSession
    private let tokenStorage: TokenStorage
    private let decoder: JSONDecoder
    private var cancellables = Set<AnyCancellable>()
    
    // WebSocket properties
    private var webSocketTask: URLSessionWebSocketTask?
    private let webSocketQueue = DispatchQueue(
        label: "com.neocore.myBrain.websocket",
        qos: .userInteractive
    )
    
    // Publishers
    private let messageSubject = PassthroughSubject<[String: Any], Never>()
    private let connectionStateSubject = PassthroughSubject<WebSocketConnectionState, Never>()
    private let chapterDataSubject = PassthroughSubject<ChapterData?, Never>()
    private let welcomeMessageSubject = PassthroughSubject<String?, Never>()
    
    var isConnected: Bool {
        return webSocketTask?.state == .running
    }
    
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
    
    init(
        baseURLString: String,
        tokenStorage: TokenStorage,
        session: URLSession = .shared
    ) {
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid baseURL: \(baseURLString)")
        }
        self.baseURL = url
        self.tokenStorage = tokenStorage
        self.session = session
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - NetworkService Implementation
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let accessToken = tokenStorage.getAccessToken() {
            request
                .setValue(
                    "Bearer \(accessToken)",
                    forHTTPHeaderField: "Authorization"
                )
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                guard let self = self else { throw NetworkError.unknown }
                return try self.validateResponse(data: data, response: response)
            }
            .decode(type: T.self, decoder: decoder)
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else {
                    return NetworkError.requestFailed(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func uploadFile(_ fileURL: URL, to endpoint: Endpoint, fileKey: String) -> AnyPublisher<UploadResponse, NetworkError> {
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request
            .setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
        
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let accessToken = tokenStorage.getAccessToken() {
            request
                .setValue(
                    "Bearer \(accessToken)",
                    forHTTPHeaderField: "Authorization"
                )
        }
        
        var body = Data()
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body
                .append(
                    "Content-Disposition: form-data; name=\"\(fileKey)\"; filename=\"\(filename)\"\r\n".data(
                        using: .utf8
                    )!
                )
            
            let mimeType = mimeTypeForExtension(fileURL.pathExtension)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
        } catch {
            return Fail(error: NetworkError.requestFailed(error))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                guard let self = self else { throw NetworkError.unknown }
                return try self.validateResponse(data: data, response: response)
            }
            .decode(type: UploadResponse.self, decoder: decoder)
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else {
                    return NetworkError.requestFailed(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    
    func fetchImage(from urlString: String) -> AnyPublisher<UIImage?, Never> {
        guard let url = URL(string: urlString) else {
            return Just(nil).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { data, _ -> UIImage? in
                return UIImage(data: data)
            }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - AuthNetworkService Implementation
    
    func login(email: String, code: String, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError> {
        let loginRequest = VerifyLoginRequest(
            email: email,
            code: code,
            device_info: deviceInfo
        )
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/login/",
            method: .post,
            body: loginRequest
        )
        
        return self.request(endpoint)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.tokenStorage
                        .saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                })
            .eraseToAnyPublisher()
    }
    
    func register(email: String, firstName: String, lastName: String) -> AnyPublisher<RegisterResponse, NetworkError> {
        let registerRequest = RegisterRequest(
            email: email,
            first_name: firstName,
            last_name: lastName
        )
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/register/",
            method: .post,
            body: registerRequest
        )
        
        return self.request(endpoint)
    }
    
    func verifyRegistration(email: String, code: String, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError> {
        let verifyRequest = VerifyRequest(
            email: email,
            code: code,
            device_info: deviceInfo
        )
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/verify/",
            method: .post,
            body: verifyRequest
        )
        
        return self.request(endpoint)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.tokenStorage
                        .saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                })
            .eraseToAnyPublisher()
    }
    
    func authenticateWithApple(userId: String, firstName: String?, lastName: String?, email: String?, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError> {
        let requestBody: [String: Any] = [
            "user_id": userId,
            "first_name": firstName ?? "",
            "last_name": lastName ?? "",
            "email": email ?? "",
            "device_info": [
                "device_name": deviceInfo.device_name,
                "os_name": deviceInfo.os_name,
                "app_version": deviceInfo.app_version,
                "unique_number": deviceInfo.unique_number
            ]
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/apple-login/",
            method: .post
        )
        
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                guard let self = self else { throw NetworkError.unknown }
                return try self.validateResponse(data: data, response: response)
            }
            .decode(type: TokenResponse.self, decoder: decoder)
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else {
                    return NetworkError.requestFailed(error)
                }
            }
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.tokenStorage
                        .saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func authenticateWithGoogle(idToken: String, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError> {
        let requestBody: [String: Any] = [
            "id_token": idToken,
            "device_info": [
                "device_name": deviceInfo.device_name,
                "os_name": deviceInfo.os_name,
                "app_version": deviceInfo.app_version,
                "unique_number": deviceInfo.unique_number
            ]
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/google-login/",
            method: .post
        )
        
        guard let url = buildURL(for: endpoint) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                guard let self = self else { throw NetworkError.unknown }
                return try self.validateResponse(data: data, response: response)
            }
            .decode(type: TokenResponse.self, decoder: decoder)
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                } else if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else {
                    return NetworkError.requestFailed(error)
                }
            }
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.tokenStorage
                        .saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    
    func refreshToken(token: String) -> AnyPublisher<TokenResponse, NetworkError> {
        let refreshRequest = ["refresh": token]
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/refresh/",
            method: .post,
            body: refreshRequest
        )
        
        return self.request(endpoint)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.tokenStorage
                        .saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                })
            .eraseToAnyPublisher()
    }
    
    func logout(refreshToken: String) -> AnyPublisher<EmptyResponse, NetworkError> {
        let logoutRequest = [
            "refresh": refreshToken,
            "unique_device_id": "unique_device_id_123"
        ]
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/logout/",
            method: .post,
            body: logoutRequest
        )
        
        return self.request(endpoint)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.tokenStorage.clearTokens()
            })
            .eraseToAnyPublisher()
    }
    
    func requestLoginCode(email: String) -> AnyPublisher<RegisterResponse, NetworkError> {
        let loginRequest = LoginRequest(email: email)
        
        let endpoint = Endpoint(
            path: "/api/v1/profiles/request/",
            method: .post,
            body: loginRequest
        )
        
        return self.request(endpoint)
    }
    
    // MARK: - ThoughtNetworkService Implementation
    
    func fetchThoughts() -> AnyPublisher<[Thought], NetworkError> {
        let endpoint = Endpoint(
            path: "/api/v1/thoughts/",
            method: .get
        )
        
        return self.request(endpoint)
    }
    
    func deleteThought(id: Int) -> AnyPublisher<EmptyResponse, NetworkError> {
        let endpoint = Endpoint(
            path: "/api/v1/thoughts/\(id)/delete/",
            method: .delete
        )
        
        return self.request(endpoint)
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
            request
                .setValue(
                    "Bearer \(accessToken)",
                    forHTTPHeaderField: "Authorization"
                )
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
        connectionStateSubject.send(.disconnected)
    }
    
    func sendMessage(action: String, data: [String: Any]) {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            // If not connected, try to reconnect
            connect()
            
            DispatchQueue.main
                .asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.sendMessage(action: action, data: data)
                }
            return
        }
        
        let message: [String: Any] = [
            "action": action,
            "data": data
        ]
        
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: message,
                options: []
            )
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
        
        setupPingTimer()
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
    
    func sendFeedback(
        thoughtId: Int,
        chapterNumber: Int,
        word: String,
        value: Double
    ) {
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
    
    private func buildURL(for endpoint: Endpoint) -> URL? {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = endpoint.path
            .hasPrefix("/") ? endpoint.path : baseURL.path + "/" + endpoint.path
        components.queryItems = endpoint.queryItems
        
        return components.url
    }
    
    private func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        let statusCode = httpResponse.statusCode
        
        switch statusCode {
        case 200...299:
            return data
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            if let errorResponse = try? JSONDecoder().decode(
                ErrorResponse.self,
                from: data
            ) {
                throw NetworkError
                    .serverError(
                        statusCode: statusCode,
                        message: errorResponse.detail
                    )
            }
            throw NetworkError
                .serverError(statusCode: statusCode, message: "Client error")
        case 500...599:
            throw NetworkError
                .serverError(statusCode: statusCode, message: "Server error")
        default:
            throw NetworkError.invalidResponse
        }
    }
    
    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "doc", "docx":
            return "application/msword"
        default:
            return "application/octet-stream"
        }
    }
    
    // MARK: - WebSocket Private Methods
    
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
                        print(
                            "Received non-text data that could not be decoded."
                        )
                    }
                @unknown default:
                    print("Received an unknown message type.")
                }
                
                self.receiveMessage()
                
            case .failure(let error):
                self.handleWebSocketError(error)
                
                DispatchQueue.main
                    .asyncAfter(deadline: .now() + 3.0) { [weak self] in
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
                connectionStateSubject
                    .send(
                        .failed(
                            NetworkError
                                .serverError(statusCode: 400, message: errorMsg)
                        )
                    )
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
            connectionStateSubject.send(.connected)
            
            DispatchQueue.main.async {
                self.welcomeMessageSubject.send(welcome)
            }
        } else {
            let fallbackMsg = message ?? "No message"
            print(
                "Received connection_response with unknown status. Message: \(fallbackMsg)"
            )
        }
    }
    
    private func handleChapterResponse(_ jsonObject: [String: Any]) {
        guard let dataPayload = jsonObject["data"] as? [String: Any] else {
            print("No chapter data found.")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: dataPayload,
                options: []
            )
            let chapterData = try decoder.decode(
                ChapterData.self,
                from: jsonData
            )
            
            DispatchQueue.main.async {
                self.chapterDataSubject.send(chapterData)
            }
        } catch {
            print("Error parsing chapter data: \(error)")
        }
    }
    
    private func handleWebSocketError(_ error: Error) {
        print("WebSocket error: \(error.localizedDescription)")
        connectionStateSubject.send(.failed(error))
    }
    
    private func setupPingTimer() {
        DispatchQueue
            .global()
            .asyncAfter(deadline: .now() + 30) { [weak self] in
                guard let self = self, self.webSocketTask != nil else { return }
                
                self.sendPing()
                self.setupPingTimer()
            }
    }
}
