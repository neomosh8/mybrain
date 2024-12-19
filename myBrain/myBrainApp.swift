import SwiftUI
import SwiftData

@main
struct myBrainApp: App {
    @StateObject var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .modelContainer(for: [AuthData.self]) // Ensure AuthData is included
        }
    }
}

