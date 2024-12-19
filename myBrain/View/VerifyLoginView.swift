import SwiftUI

struct VerifyLoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var code = ""
    @State private var errorMessage: String?
    let email: String

    var body: some View {
        Form {
            TextField("Login Code", text: $code)
                .keyboardType(.numberPad)

            Button("Verify & Login") {
                authVM.verifyLogin(email: email, code: code) { result in
                    switch result {
                    case .success:
                        // On success, navigate to main content
                        break
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .navigationTitle("Verify Code")
    }
}
