import AuthenticationServices
import SwiftUI
import CryptoKit

class AppleAuthManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    
    // Used for Apple Sign In session validation
    private var currentNonce: String?
    
    // Implement the ASAuthorizationControllerPresentationContextProviding method
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window to use for the Apple Sign In UI
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
    
    // Start the Apple Sign In flow
    func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Get user info
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            
            // Store user info
            self.userId = userIdentifier
            self.firstName = fullName?.givenName
            self.lastName = fullName?.familyName
            self.email = email
            
            // Now you can send this information to your server
            self.authenticateWithServer(userId: userIdentifier, firstName: fullName?.givenName, lastName: fullName?.familyName, email: email)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In Error: \(error.localizedDescription)")
    }
    
    // MARK: - Server Authentication
    private func authenticateWithServer(userId: String, firstName: String?, lastName: String?, email: String?) {
        // Implement your server communication here
        // This should send the Apple Sign In credentials to your backend
        // and receive access/refresh tokens in return
        
        // For example:
        // let request = AppleAuthRequest(userId: userId, firstName: firstName, lastName: lastName, email: email)
        // AuthAPIClient.authenticate(with: request) { result in
        //   // Handle result
        // }
    }
    
    // MARK: - Helpers for Apple Sign In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}
