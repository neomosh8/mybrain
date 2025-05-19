import SwiftUI

struct VerifyRegistrationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var code = ""
    @State private var errorMessage: String?
    let email: String
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        Form {
            TextField("Verification Code", text: $code)
                .keyboardType(.numberPad)

            Button("Verify") {
                authVM.verifyRegistration(email: email, code: code,context: modelContext) { result in
                    switch result {
                    case .success:
                        // On success, navigate to main content
                        // If you have a global @SceneStorage or AppStorage that triggers ContentView to show
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
        .navigationTitle("Verify Email")
    }
}
