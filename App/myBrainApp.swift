import SwiftUI
import SwiftData
import GoogleSignIn

import MediaPlayer

@main
struct myBrainApp: App {
    @StateObject var authVM = AuthViewModel()
    @StateObject var backgroundManager = BackgroundManager.shared
    
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    
    init() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        _ = NetworkServiceManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(backgroundManager)
                .modelContainer(for: [AuthData.self])
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}



class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
