import SwiftUI
import GoogleSignIn

@MainActor
final class GoogleAuthManager: ObservableObject {
    // Published state
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    
    private let clientID = "312380135422-bko7g13qv6ggt7e5cc7dlt6lsquq7qi4.apps.googleusercontent.com"
    private let baseURL  = URL(string: "https://brain.sorenapp.ir")!
    
    init() { checkSignInStatus() }
    
    // MARK: - Persisted session
    private func checkSignInStatus() {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        updateUserInfo(from: user)
        isAuthenticated = true
    }
    
    // MARK: - Sign‑in
    func signIn() {
        guard
            let scene  = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = scene.windows.first?.rootViewController
        else {
            print("RootVC not found"); return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                let user   = result.user
                updateUserInfo(from: user)
                try await authenticateWithServer(user: user)
                isAuthenticated = true
            } catch {
                print("Google Sign‑In error:", error.localizedDescription)
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        firstName = nil; lastName = nil; email = nil; userId = nil
    }
}

// MARK: - Private helpers
private extension GoogleAuthManager {
    func updateUserInfo(from user: GIDGoogleUser) {
        userId    = user.userID
        firstName = user.profile?.givenName
        lastName  = user.profile?.familyName
        email     = user.profile?.email
    }
    
    // Send token to server
    func authenticateWithServer(user: GIDGoogleUser) async throws {
        guard let idToken = user.idToken?.tokenString else {
            print("ID Token not found"); return
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/profiles/google-login/"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceInfo: [String: Any] = [
            "device_name": UIDevice.current.name,
            "os_name":     UIDevice.current.systemVersion,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "unique_number": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        let body: [String: Any] = [
            "id_token":    idToken,
            "device_info": deviceInfo
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenRes  = try JSONDecoder().decode(TokenResponse.self, from: data)
                
        NotificationCenter.default.post(name: .didReceiveAuthTokens,
                                        object: nil,
                                        userInfo: ["access": tokenRes.access,
                                                   "refresh": tokenRes.refresh])
    }
}
