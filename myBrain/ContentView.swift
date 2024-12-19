import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject var authVM = AuthViewModel()

    var body: some View {
        // After initializing authVM, load tokens from SwiftData:
        // This will restore login state if tokens exist
        Group {
            if authVM.isAuthenticated {
                Text("Welcome to myBrain!")
            } else {
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
            authVM.loadFromSwiftData(context: modelContext)
        }
    }
}
