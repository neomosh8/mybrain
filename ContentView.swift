import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    // Added for BLE onboarding
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @State private var showOnboarding = false
    @State private var hasCheckedBLEStatus = false
    
    init() {
        _bluetoothService = StateObject(wrappedValue: BluetoothService.shared)
        let viewModel = OnboardingViewModel(bluetoothService: BluetoothService.shared)
        _onboardingViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if authVM.isAuthenticated {
                // Show main content or ThoughtsView
                NavigationStack {
                    ThoughtsView(accessToken: authVM.accessToken ?? "")
                        .environmentObject(bluetoothService) // Pass BLE service to ThoughtsView
                }
                .overlay {
                    if showOnboarding {
                        OnboardingView(viewModel: onboardingViewModel, bluetoothService: bluetoothService)
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
            // Load tokens from SwiftData when the view appears
            authVM.loadFromSwiftData(context: modelContext)
            
            // Check BLE status when authenticated
            if authVM.isAuthenticated && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
        .onChange(of: authVM.isAuthenticated) { newValue in
            if newValue && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
        .onChange(of: onboardingViewModel.hasCompletedOnboarding) { completed in
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
