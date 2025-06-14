import SwiftUI
import SwiftData
import GoogleSignIn
import MediaPlayer

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    // Added for BLE onboarding
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @State private var showOnboarding = false
    @State private var hasCheckedBLEStatus = false
    
    // Services
    private let serverConnectFactory: ServerConnectFactory
    
    init() {
        // Initialize BluetoothService
        _bluetoothService = StateObject(wrappedValue: BluetoothService.shared)
        
        // Initialize OnboardingViewModel
        let viewModel = OnboardingViewModel(
            bluetoothService: BluetoothService.shared
        )
        _onboardingViewModel = StateObject(wrappedValue: viewModel)
        
        // Initialize the ServerConnectFactory (don't create actual ServerConnect yet)
        serverConnectFactory = ServerConnectFactory()
    }
    
    var body: some View {
        Group {
            if authVM.isAuthenticated && authVM.isProfileComplete {
                // Show MainTabView instead of ThoughtsView
                NavigationStack {
                    MainTabView()
                        .environmentObject(bluetoothService) // Pass BluetoothService to MainTabView
                }
                .overlay {
                    if showOnboarding {
                        OnboardingView(
                            viewModel: onboardingViewModel,
                            bluetoothService: bluetoothService
                        )
                        .transition(.opacity)
                        .animation(.easeInOut, value: showOnboarding)
                    }
                }
            } else {
                NavigationStack {
                    LoginScreen()
                        .environmentObject(authVM)
                }
            }
        }
        .onAppear {
            // Initialize AuthViewModel with ServerConnect if not already done
            if authVM.serverConnect == nil {
                print("Initializing ServerConnect on app appear")
                let serverConnect = serverConnectFactory.shared(with: modelContext)
                
                serverConnect.resetSession()
                
                authVM.initializeWithServerConnect(serverConnect)
            }
            
            // Load tokens from SwiftData when the view appears
            authVM.loadFromSwiftData(context: modelContext)
            
            // Check BLE status when authenticated
            if authVM.isAuthenticated && authVM.isProfileComplete && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
        .onChange(of: authVM.isAuthenticated) { _, newValue in
            if newValue && authVM.isProfileComplete && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
        .onChange(of: authVM.isProfileComplete) { _, newValue in
            if newValue && authVM.isAuthenticated && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
        .onChange(
            of: onboardingViewModel.hasCompletedOnboarding
        ) { _, completed in
            if completed {
                withAnimation {
                    showOnboarding = false
                }
            }
        }
    }
    
    private func checkBLEStatus() {
        hasCheckedBLEStatus = true
        
        // If not connected, try to auto-reconnect first
        if !bluetoothService.isConnected {
            // Show the reconnecting UI
            withAnimation {
                showOnboarding = true
                onboardingViewModel.checkForPreviousDevice()
            }
        }
    }
}
