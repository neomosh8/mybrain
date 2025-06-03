import SwiftUICore
import SwiftUI

struct VerifyCodeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var showProfileCompletion = false
    let email: String
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Form {
            TextField("Verification Code", text: $code)
                .keyboardType(.numberPad)
            
            Button("Verify") {
                authVM.verifyCode(email: email, code: code, context: modelContext) { result in
                    switch result {
                    case .success(let isProfileComplete):
                        if !isProfileComplete {
                            showProfileCompletion = true
                        }
                        // If profile complete, we're already authenticated
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
        .navigationDestination(isPresented: $showProfileCompletion) {
            CompleteProfileView().environmentObject(authVM)
        }
    }
}
