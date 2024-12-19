import SwiftUI

@main
struct myBrainApp: App {
    @StateObject var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
        }
    }
}
