import SwiftUI
import SwiftData
import GoogleSignIn
import MediaPlayer

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    // Added for BLE onboarding
    @StateObject private var bluetoothService = BTService()
    @State private var showOnboarding = false
    @State private var hasCheckedBLEStatus = false
    @State private var isLoadingAuthState = true
    
    init() {
        _bluetoothService = StateObject(wrappedValue: BTService.shared)
    }
    
    var body: some View {
        Group {
            if isLoadingAuthState {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image("AppLogoSVG")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.white)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
            } else if authVM.isAuthenticated && authVM.isProfileComplete {
                NavigationStack {
                    MainTabView()
                        .environmentObject(bluetoothService)
                }
            } else {
                NavigationStack {
                    LoginScreen()
                        .environmentObject(authVM)
                }
            }
        }
        .onAppear {
            loadAuthenticationState()
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
    }
    
    private func loadAuthenticationState() {
        // Load tokens from SwiftData when the view appears
        authVM.loadFromSwiftData(context: modelContext)
        
        // Small delay to ensure data is loaded properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isLoadingAuthState = false
            }
            
            // Check BLE status when authenticated
            if authVM.isAuthenticated && authVM.isProfileComplete && !hasCheckedBLEStatus {
                checkBLEStatus()
            }
        }
    }
    
    private func checkBLEStatus() {
        hasCheckedBLEStatus = true
    }
}
