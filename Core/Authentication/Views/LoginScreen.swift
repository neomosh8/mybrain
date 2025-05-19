import SwiftUI
import SwiftData

struct LoginScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 30) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text("Welcome to MyBrain")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose how you'd like to sign in")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            SocialLoginView()
                .padding(.top, 20)
            
            Divider()
                .padding(.vertical, 20)
            
            // Your existing email login
            Text("or sign in with email")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            NavigationLink("Sign in with Email", destination: LoginView().environmentObject(authVM))
                .padding()
            
            NavigationLink("Create an Account", destination: RegisterView().environmentObject(authVM))
                .padding()
        }
        .padding()
    }
}
