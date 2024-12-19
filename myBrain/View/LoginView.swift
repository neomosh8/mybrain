import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var showVerify = false

    var body: some View {
        Form {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            Button("Request Login Code") {
                authVM.requestLoginCode(email: email) { result in
                    switch result {
                    case .success:
                        showVerify = true
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
            }

            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            NavigationLink(
                destination: VerifyLoginView(email: email).environmentObject(authVM),
                isActive: $showVerify
            ) {
                EmptyView()
            }.hidden()
        }
        .navigationTitle("Login")
    }
}
