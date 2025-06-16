import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var logoutErrorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Profile icon
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Profile")
                .font(.title)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Logout button
            Button(action: {
                logout()
            }) {
                HStack {
                    if isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "arrow.right.square")
                    }
                    Text(isLoggingOut ? "Signing Out..." : "Sign Out")
                }
                .foregroundColor(.white)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isLoggingOut)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .navigationTitle("Profile")
        .alert("Logout Error", isPresented: $showLogoutError) {
            Button("OK") { }
        } message: {
            Text(logoutErrorMessage)
        }
    }
    
    private func logout() {
        isLoggingOut = true
        
        authVM.logout(context: modelContext) { result in
            DispatchQueue.main.async {
                isLoggingOut = false
                
                switch result {
                case .success:
                    print("✅ Logout successful")
                    // The ContentView will automatically show LoginScreen
                case .failure(let error):
                    print("❌ Logout failed: \(error)")
                    logoutErrorMessage = error.localizedDescription
                    showLogoutError = true
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
