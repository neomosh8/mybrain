import SwiftUICore
import SwiftUI

struct CompleteProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Text("Complete Your Profile")
                .font(.headline)
                .padding(.bottom)
            
            TextField("First Name", text: $firstName)
            TextField("Last Name", text: $lastName)
            
            Button("Save Profile") {
                authVM.updateProfile(firstName: firstName, lastName: lastName) { result in
                    switch result {
                    case .success:
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
        .navigationTitle("Complete Profile")
    }
}
