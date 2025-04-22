import SwiftUI
import GoogleSignIn

struct SocialLoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Apple Sign‑In
            Button {
                authVM.appleAuthManager.startSignInWithAppleFlow()
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Sign in with Apple")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(Color.black)
                .cornerRadius(10)
            }
            
            // Google Sign‑In
            Button {
                authVM.googleAuthManager.signIn()
            } label: {
                HStack {
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Sign in with Google")
                        .font(.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 55)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3))
                )
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        
        // SignIn result (Apple)
        .onReceive(authVM.appleAuthManager.$userId) { userId in
            guard
                let userId,
                let first = authVM.appleAuthManager.firstName,
                let last  = authVM.appleAuthManager.lastName,
                let mail  = authVM.appleAuthManager.email
            else { return }
            
            authVM.authenticateWithApple(
                context: modelContext,
                userId: userId,
                firstName: first,
                lastName: last,
                email: mail
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = nil
                }
            }
        }
        
        // SignIn result (Google)
        .onReceive(authVM.googleAuthManager.$userId) { _ in
            Task { @MainActor in
                guard var user = GIDSignIn.sharedInstance.currentUser else { return }
                
                do { user = try await user.refreshTokensIfNeeded() } catch { }
                
                if let idTokenString = user.idToken?.tokenString {
                    authVM.authenticateWithGoogle(
                        context: modelContext,
                        idToken: idTokenString
                    ) { result in
                        if case .failure(let error) = result {
                            errorMessage = error.localizedDescription
                        } else {
                            errorMessage = nil
                        }
                    }
                } else {
                    errorMessage = "Google ID Token not founded"
                }
            }
        }
    }
}
