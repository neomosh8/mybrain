import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        if authVM.isAuthenticated {
            // Show main app content here
            Text("Welcome to myBrain!")
        } else {
            // Show login/register flow if not authenticated
            NavigationStack {
                VStack {
                    NavigationLink("Register", destination: RegisterView().environmentObject(authVM))
                    NavigationLink("Login", destination: LoginView().environmentObject(authVM))
                }
                .navigationTitle("MyBrain Auth")
            }
        }
    }
}
