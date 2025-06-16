import Foundation
import Security

final class SecureTokenStorage: TokenStorage {
    private let accessTokenKey = "myBrain.accessToken"
    private let refreshTokenKey = "myBrain.refreshToken"
    
    func saveTokens(accessToken: String, refreshToken: String) {
        KeychainHelper.save(accessToken, forKey: accessTokenKey)
        KeychainHelper.save(refreshToken, forKey: refreshTokenKey)
    }
    
    func getAccessToken() -> String? {
        return KeychainHelper.load(forKey: accessTokenKey)
    }
    
    func getRefreshToken() -> String? {
        return KeychainHelper.load(forKey: refreshTokenKey)
    }
    
    func clearTokens() {
        KeychainHelper.delete(forKey: accessTokenKey)
        KeychainHelper.delete(forKey: refreshTokenKey)
    }
}
