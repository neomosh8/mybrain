import Foundation
import Combine

/// Main network service singleton that provides access to all networking capabilities
final class NetworkServiceManager {
    static let shared = NetworkServiceManager()
    
    private let httpService: HTTPNetworkService
    private let webSocketService: WebSocketNetworkService
    private let tokenStorage: TokenStorage
    
    private init() {
        self.tokenStorage = SecureTokenStorage()
        self.httpService = HTTPNetworkService(
            baseURL: NetworkConstants.baseURL,
            tokenStorage: tokenStorage
        )
        self.webSocketService = WebSocketNetworkService(
            baseURL: NetworkConstants.webSocketBaseURL,
            tokenStorage: tokenStorage
        )
    }
    
    func configure(baseURL: String, webSocketURL: String) {
        // Re-initialize services with new URLs if needed during development
    }
    
    // MARK: - HTTP API Access
    var auth: AuthenticationAPI { httpService }
    var profile: ProfileAPI { httpService }
    var thoughts: ThoughtsAPI { httpService }
    var entertainment: EntertainmentAPI { httpService }
    
    // MARK: - WebSocket Access
    var webSocket: WebSocketAPI { webSocketService }
    
    // MARK: - Token Management
    var hasValidToken: Bool {
        tokenStorage.getAccessToken() != nil
    }
    
    func clearAllTokens() {
        tokenStorage.clearTokens()
    }
}
