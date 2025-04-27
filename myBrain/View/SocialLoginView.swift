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
    }
}
