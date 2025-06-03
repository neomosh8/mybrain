import SwiftUICore
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var showVerification = false
    
    var body: some View {
        Form {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            Button("Request Code") {
                authVM.requestAuthCode(email: email) { result in
                    switch result {
                    case .success:
                        showVerification = true
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .navigationTitle("Sign In / Register")
        .navigationDestination(isPresented: $showVerification) {
            VerifyCodeView(email: email).environmentObject(authVM)
        }
    }
}
