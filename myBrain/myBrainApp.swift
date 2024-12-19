import SwiftUI
import SwiftData

@main
struct myBrainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [AuthData.self]) // Ensure AuthData is included in the model container
    }
}
