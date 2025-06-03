import SwiftUI
import Combine
import GoogleSignIn

struct SocialLoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var errorMessage: String?
    @State private var showProfileCompletion = false
    @State private var cancellables = Set<AnyCancellable>()

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
        .onAppear {
            NotificationCenter.default.publisher(for: .appleAuthSuccess)
                .sink { notification in
                    guard let userId = notification.userInfo?["userId"] as? String,
                          let firstName = notification.userInfo?["firstName"] as? String,
                          let lastName = notification.userInfo?["lastName"] as? String,
                          let email = notification.userInfo?["email"] as? String else {
                        return
                    }
                    
                    authVM.authenticateWithApple(
                        context: modelContext,
                        userId: userId,
                        firstName: firstName,
                        lastName: lastName,
                        email: email
                    ) { result in
                        switch result {
                        case .success(let isProfileComplete):
                            if !isProfileComplete {
                                showProfileCompletion = true
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .store(in: &cancellables)

            // Set up notification observers for Google Sign-In
            NotificationCenter.default.publisher(for: .googleAuthSuccess)
                .sink { notification in
                    guard let idToken = notification.userInfo?["idToken"] as? String else {
                        return
                    }
                    
                    authVM.authenticateWithGoogle(
                        context: modelContext,
                        idToken: idToken
                    ) { result in
                        switch result {
                        case .success(let isProfileComplete):
                            if !isProfileComplete {
                                showProfileCompletion = true
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .store(in: &cancellables)
        }
        .navigationDestination(isPresented: $showProfileCompletion) {
            CompleteProfileView().environmentObject(authVM)
        }
    }
}
