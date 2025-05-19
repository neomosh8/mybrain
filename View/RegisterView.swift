import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage: String?
    @State private var showVerification = false

    var body: some View {
        VStack {
            Form {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)

                Button("Register") {
                    authVM.register(email: email, firstName: firstName, lastName: lastName) { result in
                        switch result {
                        case .success:
                            showVerification = true
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            NavigationLink(
                destination: VerifyRegistrationView(email: email).environmentObject(authVM),
                isActive: $showVerification
            ) {
                EmptyView()
            }.hidden()
        }
        .navigationTitle("Register")
    }
}
