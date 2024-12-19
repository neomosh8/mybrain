import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Group {
            if authVM.isAuthenticated {
                // Show main content or ThoughtsView
                NavigationStack {
                    ThoughtsView(accessToken: authVM.accessToken ?? "")
                }
            } else {
                // Show login/register flow
                NavigationStack {
                    VStack {
                        NavigationLink("Register", destination: RegisterView().environmentObject(authVM))
                        NavigationLink("Login", destination: LoginView().environmentObject(authVM))
                    }
                    .navigationTitle("MyBrain Auth")
                }
            }
        }
        .onAppear {
            // Load tokens from SwiftData when the view appears
            authVM.loadFromSwiftData(context: modelContext)
        }
    }
}
