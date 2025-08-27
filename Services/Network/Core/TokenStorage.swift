import Foundation
import Security

final class SecureTokenStorage: TokenStorage {
    private let accessTokenKey = "myBrain.accessToken"
    private let refreshTokenKey = "myBrain.refreshToken"
    
    func saveTokens(accessToken: String, refreshToken: String) {
        do {
            try KeychainHelper.save(accessToken, forKey: accessTokenKey)
            try KeychainHelper.save(refreshToken, forKey: refreshTokenKey)
        } catch {
            print("Keychain save error:", error)
        }
    }
    
    func getAccessToken() -> String? {
        do { return try KeychainHelper.load(forKey: accessTokenKey) }
        catch { print("Keychain load access error:", error); return nil }
    }

    func getRefreshToken() -> String? {
        do { return try KeychainHelper.load(forKey: refreshTokenKey) }
        catch { print("Keychain load refresh error:", error); return nil }
    }

    func clearTokens() {
        _ = KeychainHelper.delete(forKey: accessTokenKey)
        _ = KeychainHelper.delete(forKey: refreshTokenKey)
    }
}
