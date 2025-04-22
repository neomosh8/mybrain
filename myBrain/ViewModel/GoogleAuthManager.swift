import Foundation
import GoogleSignIn
import SwiftUI

@MainActor
class GoogleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var firstName: String?
    @Published var lastName: String?
    @Published var email: String?
    @Published var userId: String?
    
    private let clientID = "312380135422-bko7g13qv6ggt7e5cc7dlt6lsquq7qi4.apps.googleusercontent.com"
    
    init() {
        checkSignInStatus()
    }
    
    // last login check
    func checkSignInStatus() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            updateUserInfo(user: user)
            isAuthenticated = true
        }
    }
    
    func signIn() {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            print("Root VC پیدا نشد")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                let user = result.user
                updateUserInfo(user: user)
                authenticateWithServer(user: user)
                isAuthenticated = true
            } catch {
                print("Google Sign‑In error: \(error.localizedDescription)")
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
    }
    
    private func updateUserInfo(user: GIDGoogleUser) {
        userId     = user.userID
        firstName  = user.profile?.givenName
        lastName   = user.profile?.familyName
        email      = user.profile?.email
    }
    
    // send token to server
    private func authenticateWithServer(user: GIDGoogleUser) {
        if let idTokenString = user.idToken?.tokenString {
            print("Got ID token: \(idTokenString)")
            // Send idTokenString to backend
        } else {
            print("ID Token بازیابی نشد")
        }
    }
}
