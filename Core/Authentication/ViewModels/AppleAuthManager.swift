import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
final class AppleAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    
    private var currentNonce: String?
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsKeyPrefix = "AppleAuth_"
    
    override init() {
        super.init()
        checkExistingSession()
    }
    
    // MARK: - Session Management
    
    private func checkExistingSession() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        if let userID = UserDefaults.standard.string(forKey: "AppleUserID") {
            appleIDProvider
                .getCredentialState(forUserID: userID) { state, error in
                    DispatchQueue.main.async {
                        switch state {
                        case .authorized:
                            self.userId = userID
                            self.loadUserDataLocally(for: userID)
                        default:
                            break
                        }
                    }
                }
        }
    }
    
    // MARK: - Sign-In Flow
    
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(
            authorizationRequests: [request]
        )
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - User Data Storage
    
    private func saveUserDataLocally() {
        guard let userId = userId else { return }
        
        UserDefaults.standard.set(userId, forKey: "AppleUserID")
        
        if let firstName = firstName {
            UserDefaults.standard
                .set(
                    firstName,
                    forKey: userDefaultsKeyPrefix + userId + "_firstName"
                )
        }
        
        if let lastName = lastName {
            UserDefaults.standard
                .set(
                    lastName,
                    forKey: userDefaultsKeyPrefix + userId + "_lastName"
                )
        }
        
        if let email = email {
            UserDefaults.standard
                .set(email, forKey: userDefaultsKeyPrefix + userId + "_email")
        }
    }
    
    private func loadUserDataLocally(for userId: String) {
        firstName = UserDefaults.standard
            .string(forKey: userDefaultsKeyPrefix + userId + "_firstName")
        lastName = UserDefaults.standard
            .string(forKey: userDefaultsKeyPrefix + userId + "_lastName")
        email = UserDefaults.standard
            .string(forKey: userDefaultsKeyPrefix + userId + "_email")
    }
    
    func signOut() {
        isAuthenticated = false

        NotificationCenter.default.post(
            name: Notification.Name("AppleSignOutNotification"),
            object: nil
        )
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleAuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first!
    }
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        
        userId = credential.user
        
        if let givenName = credential.fullName?.givenName {
            firstName = givenName
        }
        
        if let familyName = credential.fullName?.familyName {
            lastName = familyName
        }
        
        if let userEmail = credential.email {
            email = userEmail
        }
        
        if let userId = userId, (
            firstName == nil || lastName == nil || email == nil
        ) {
            loadUserDataLocally(for: userId)
        }
        
        saveUserDataLocally()
        
        NotificationCenter.default.post(
            name: .appleAuthSuccess,
            object: nil,
            userInfo: [
                "userId": userId ?? "",
                "firstName": firstName ?? "",
                "lastName": lastName ?? "",
                "email": email ?? ""
            ]
        )
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("Apple Sign-In error:", error.localizedDescription)
        
        NotificationCenter.default.post(
            name: .appleAuthFailure,
            object: nil,
            userInfo: ["error": error]
        )
    }
}

// MARK: - Helpers (nonce + SHA-256)
private extension AppleAuthManager {
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remaining = length
        
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce.")
            }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }
    
    func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256
            .hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let didReceiveAuthTokens = Notification.Name("didReceiveAuthTokens")
    static let appleAuthSuccess = Notification.Name("appleAuthSuccess")
    static let appleAuthFailure = Notification.Name("appleAuthFailure")
}
