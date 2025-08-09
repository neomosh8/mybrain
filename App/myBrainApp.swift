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
                .modelContainer(for: [AuthData.self, UserProfileData.self])
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if networkService.hasValidToken {
            networkService.connectWebSocketIfAuthenticated()
        }
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        networkService.disconnectWebSocket()
        SignalProcessing.cleanupFFTSetups()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Keep WebSocket connected in background for real-time updates
        // WebSocket will be maintained by background modes
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if networkService.hasValidToken && !networkService.webSocket.isConnected {
            networkService.connectWebSocketIfAuthenticated()
        }
    }
}
