import SwiftUI
import AuthenticationServices
import CryptoKit

extension Notification.Name {
    static let didReceiveAuthTokens = Notification.Name("didReceiveAuthTokens")
}

@MainActor
final class AppleAuthManager: NSObject, ObservableObject {
    // Published state
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    
    private var currentNonce: String?
    private let baseURL = URL(string: "https://brain.sorenapp.ir")!
    private let userDefaultsKeyPrefix = "AppleAuth_"
    
    // MARK: - Presentation Anchor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first!
    }
    
    // MARK: - Sign‑in Flow
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request  = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce           = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - User Data Storage
    private func saveUserDataLocally() {
        guard let userId = userId else { return }
        
        if let firstName = firstName {
            UserDefaults.standard.set(firstName, forKey: userDefaultsKeyPrefix + userId + "_firstName")
        }
        
        if let lastName = lastName {
            UserDefaults.standard.set(lastName, forKey: userDefaultsKeyPrefix + userId + "_lastName")
        }
        
        if let email = email {
            UserDefaults.standard.set(email, forKey: userDefaultsKeyPrefix + userId + "_email")
        }
    }
    
    private func loadUserDataLocally(for userId: String) {
        if firstName == nil {
            firstName = UserDefaults.standard.string(forKey: userDefaultsKeyPrefix + userId + "_firstName")
        }
        
        if lastName == nil {
            lastName = UserDefaults.standard.string(forKey: userDefaultsKeyPrefix + userId + "_lastName")
        }
        
        if email == nil {
            email = UserDefaults.standard.string(forKey: userDefaultsKeyPrefix + userId + "_email")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        
        userId = credential.user
        
        // Save data if Apple provides it (typically only on first login)
        if let givenName = credential.fullName?.givenName {
            firstName = givenName
        }
        
        if let familyName = credential.fullName?.familyName {
            lastName = familyName
        }
        
        if let userEmail = credential.email {
            email = userEmail
        }
        
        // Load previously saved data if necessary
        if let userId = userId, (firstName == nil || lastName == nil || email == nil) {
            loadUserDataLocally(for: userId)
        }
        
        // Save any new data we received
        saveUserDataLocally()
        
        Task { await authenticateWithServer() }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign‑In error:", error.localizedDescription)
    }
}

// MARK: - Server‑side auth
extension AppleAuthManager {
    private func authenticateWithServer() async {
        guard let userId else { return }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/profiles/apple-login/"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceInfo: [String: Any] = [
            "device_name": UIDevice.current.name,
            "os_name":     UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "unique_number": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        let body: [String: Any] = [
            "user_id":     userId,
            "first_name":  firstName ?? "",
            "last_name":   lastName  ?? "",
            "email":       email     ?? "",
            "device_info": deviceInfo
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
               
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse {
                print("Status:", http.statusCode,
                      "Content-Type:", http.value(forHTTPHeaderField: "Content-Type") ?? "nil")
            }
            
            let tokenRes = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            isAuthenticated = true
            
            // Send tokens for Other parts of the app
            NotificationCenter.default.post(name: .didReceiveAuthTokens,
                                            object: nil,
                                            userInfo: ["access": tokenRes.access,
                                                       "refresh": tokenRes.refresh])
        } catch {
            print("Apple auth server error:", error.localizedDescription)
        }
    }
}

// MARK: - Helpers (nonce + SHA‑256)
private extension AppleAuthManager {
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result  = ""
        var remaining = length
        
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { fatalError("Unable to generate nonce.") }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }
    
    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
