import SwiftUI
import Combine

struct LoginScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var errorMessage: String? = nil
    @State private var isRequestingCode = false
    @State private var showVerificationView = false
    @State private var showProfileCompletion = false

    var body: some View {
        Spacer()
        VStack(spacing: 24) {
            // First row: Logo and app name
            HStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                
                Text("MyBrain")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top, 40)
            
            // Welcome text
            Text("Welcome")
                .font(.system(size: 36, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
            
            if !showVerificationView {
                // Email field
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Continue button
                Button(action: {
                    // Request verification code
                    isRequestingCode = true
                    authVM.requestAuthCode(email: email) { result in
                        isRequestingCode = false
                        switch result {
                        case .success:
                            withAnimation {
                                showVerificationView = true
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    if isRequestingCode {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(email.isEmpty || isRequestingCode)
                
                // Divider with OR
                HStack {
                    VStack { Divider() }.padding(.horizontal, 8)
                    Text("OR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack { Divider() }.padding(.horizontal, 8)
                }
                .padding(.vertical)
                
                // Social sign-in buttons
                Button(action: {
                    authVM.appleAuthManager.startSignInWithAppleFlow()
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .imageScale(.medium)
                        Text("Continue with Apple")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                }
                .foregroundColor(.black)
                
                Button(action: {
                    authVM.googleAuthManager.signIn()
                }) {
                    HStack {
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                }
                .foregroundColor(.black)
                
                Spacer()
            } else {
                // Verification code field
                TextField("Verification Code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // Verify button
                Button(action: {
                    authVM.verifyCode(email: email, code: verificationCode, context: modelContext) { result in
                        switch result {
                        case .success(let isProfileComplete):
                            if !isProfileComplete {
                                showProfileCompletion = true
                            }
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Terms and Privacy
            HStack(spacing: 8) {
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                Text("|")
                    .foregroundColor(.gray)
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.footnote)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .overlay(
            Group {
                if showVerificationView {
                    Button(action: {
                        withAnimation {
                            showVerificationView = false
                            verificationCode = ""
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }, alignment: .topLeading
        )
    }
}
