import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel

    private let serverConnectFactory = ServerConnectFactory()

    var body: some View {
        Group {
            if authVM.isAuthenticated && authVM.isProfileComplete {
                MainTabView()
            } else {
                LoginScreen()
            }
        }
        .onAppear {
            if authVM.serverConnect == nil {
                let serverConnect = serverConnectFactory.shared(with: modelContext)
                authVM.initializeWithServerConnect(serverConnect)
            }
            authVM.loadFromSwiftData(context: modelContext)
        }
    }
}
