import SwiftUI
import GoogleSignIn
import Combine

@MainActor
final class GoogleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    @Published var profilePictureURL: URL?
    
    private var cancellables = Set<AnyCancellable>()
    private let clientID = "312380135422-bko7g13qv6ggt7e5cc7dlt6lsquq7qi4.apps.googleusercontent.com"
    
    init() {
        checkSignInStatus()
    }
    
    // MARK: - Session Management
    
    private func checkSignInStatus() {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return }
        updateUserInfo(from: user)
    }
    
    // MARK: - Sign-In
    
    func signIn() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = scene.windows.first?.rootViewController
        else {
            print("RootVC not found")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID
        )
        
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: rootVC
                )
                let user = result.user
                updateUserInfo(from: user)
                
                if let idToken = user.idToken?.tokenString {
                    NotificationCenter.default.post(
                        name: .googleAuthSuccess,
                        object: nil,
                        userInfo: ["idToken": idToken]
                    )
                } else {
                    throw NSError(
                        domain: "GoogleSignIn",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "ID Token not found"]
                    )
                }
            } catch {
                print("Google Sign-In error:", error.localizedDescription)
                
                NotificationCenter.default.post(
                    name: .googleAuthFailure,
                    object: nil,
                    userInfo: ["error": error]
                )
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        firstName = nil
        lastName = nil
        email = nil
        userId = nil
        profilePictureURL = nil
        
        NotificationCenter.default.post(
            name: Notification.Name("GoogleSignOutNotification"),
            object: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateUserInfo(from user: GIDGoogleUser) {
        userId = user.userID
        firstName = user.profile?.givenName
        lastName = user.profile?.familyName
        email = user.profile?.email
        profilePictureURL = user.profile?.imageURL(withDimension: 100)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let googleAuthSuccess = Notification.Name("googleAuthSuccess")
    static let googleAuthFailure = Notification.Name("googleAuthFailure")
}
