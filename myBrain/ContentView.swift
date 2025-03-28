import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    // BLE Manager
    @StateObject private var bleManager = BLEManager.shared
    
    // State
    @State private var isOnboardingComplete = false
    @State private var isAutoConnecting = false
    @AppStorage("hasCompletedBLEOnboarding") private var hasCompletedBLEOnboarding = false
    
    var body: some View {
        Group {
            if authVM.isAuthenticated {
                // Flow when user is authenticated
                if isAutoConnecting {
                    // Show auto-connect process
                    AutoConnectLoadingView(
                        bleManager: bleManager,
                        isComplete: $isAutoConnecting
                    )
                } else if !hasCompletedBLEOnboarding && !bleManager.isConnected {
                    // Show onboarding if not done yet
                    OnboardingView(
                        bleManager: bleManager,
                        isOnboardingComplete: $isOnboardingComplete
                    )
                    .onChange(of: isOnboardingComplete) { newValue in
                        if newValue {
                            hasCompletedBLEOnboarding = true
                        }
                    }
                } else {
                    // Main content
                    NavigationStack {
                        ThoughtsView(accessToken: authVM.accessToken ?? "")
                            .environmentObject(bleManager)
                    }
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
            
            // Attempt auto-connect if needed
            if authVM.isAuthenticated && hasCompletedBLEOnboarding && !bleManager.isConnected {
                // Only show auto-connect screen if Bluetooth is powered on
                if bleManager.bluetoothState == .poweredOn {
                    isAutoConnecting = true
                    bleManager.attemptAutoConnect()
                }
            }
        }
    }
}
