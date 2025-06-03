import Foundation
import UIKit
import Combine

// MARK: - Base Network Protocols

/// Protocol for handling HTTP requests
protocol NetworkService {
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError>
    
    func uploadFile(_ fileURL: URL, to endpoint: Endpoint, fileKey: String) -> AnyPublisher<UploadResponse, NetworkError>
    
    func fetchImage(from urlString: String) -> AnyPublisher<UIImage?, Never>
}

/// Protocol for authentication operations
protocol AuthNetworkService {
    func requestAuthCode(email: String) -> AnyPublisher<RegisterResponse, NetworkError>
    
    func verifyCode(email: String, code: String, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError>
    
    func updateProfile(firstName: String, lastName: String) -> AnyPublisher<EmptyResponse, NetworkError>

    func authenticateWithApple(userId: String, firstName: String?, lastName: String?, email: String?, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError>
    
    func authenticateWithGoogle(idToken: String, deviceInfo: DeviceInfo) -> AnyPublisher<TokenResponse, NetworkError>
    
    func refreshToken(token: String) -> AnyPublisher<TokenResponse, NetworkError>
    
    func logout(refreshToken: String) -> AnyPublisher<EmptyResponse, NetworkError>
}

/// Protocol for thought-related operations
protocol ThoughtNetworkService {
    func fetchThoughts() -> AnyPublisher<[Thought], NetworkError>
    
    func deleteThought(id: Int) -> AnyPublisher<EmptyResponse, NetworkError>
}

/// Protocol for WebSocket operations
protocol WebSocketService: AnyObject {
    func connect()
    
    func disconnect()
    
    func sendMessage(action: String, data: [String: Any])
    
    func sendPing()
    
    var isConnected: Bool { get }
    
    var messagePublisher: AnyPublisher<[String: Any], Never> { get }
    
    var connectionStatePublisher: AnyPublisher<WebSocketConnectionState, Never> {
        get
    }
    
    func configureForBackgroundOperation()
}

/// Protocol for thought-specific WebSocket operations
protocol ThoughtWebSocketService {
    func requestNextChapter(thoughtId: Int, generateAudio: Bool)
    
    func requestThoughtStatus(thoughtId: Int)
    
    func requestStreamingLinks(thoughtId: Int)
    
    func sendFeedback(thoughtId: Int, chapterNumber: Int, word: String, value: Double)
    
    func resetReading(thoughtId: Int)
    
    func getFeedbacks(thoughtId: Int)
    
    var chapterDataPublisher: AnyPublisher<ChapterData?, Never> { get }
    
    var welcomeMessagePublisher: AnyPublisher<String?, Never> { get }
}

/// Protocol for token storage
protocol TokenStorage {
    func saveTokens(accessToken: String, refreshToken: String)
    
    func getAccessToken() -> String?
    
    func getRefreshToken() -> String?
    
    func clearTokens()
}

// MARK: - WebSocket Specific Types

/// WebSocket connection states
enum WebSocketConnectionState {
    case connecting
    case connected
    case disconnected
    case failed(Error)
}
