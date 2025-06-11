import SwiftUI
import Combine

struct LoginScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage: String? = nil
    @State private var isRequestingCode = false
    @State private var showVerificationView = false
    @State private var showProfileCompletion = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var formOffset: CGFloat = 30
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating orbs for ambiance
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.purple.opacity(0.08))
                    .frame(width: 150, height: 150)
                    .blur(radius: 25)
                    .offset(x: 150, y: 300)
                
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // Header section with logo and title
                    VStack(spacing: 24) {
                        // Logo with glow effect
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 120, height: 120)
                                .blur(radius: 30)
                            
                            Image("AppLogoSVG")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .foregroundColor(.white)
                        }
                        .scaleEffect(logoScale)
                        
                        VStack(spacing: 8) {
                            Text("MyBrain")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Enhance your cognitive potential")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Form section
                    VStack(spacing: 32) {
                        if showProfileCompletion {
                            profileCompletionSection
                        } else if showVerificationView {
                            verificationSection
                        } else {
                            emailLoginSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .offset(y: formOffset)
                    .opacity(contentOpacity)
                    
                    Spacer()
                    
                    // Footer
                    footerSection
                        .opacity(contentOpacity)
                }
            }
        }
        .onAppear {
            setupSocialAuthNotifications()
            animateEntrance()
            
            if authVM.isAuthenticated && !authVM.isProfileComplete {
                showProfileCompletion = true
            }
        }
    }
    
    // MARK: - Email Login Section
    private var emailLoginSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)
                    
                    ZStack(alignment: .leading) {
                        if email.isEmpty {
                            Text("Enter your email")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .accentColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Continue button with gradient
                Button(action: requestAuthCode) {
                    HStack {
                        if isRequestingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(email.isEmpty || isRequestingCode)
                .opacity(email.isEmpty ? 0.6 : 1.0)
            }
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Social login buttons
            VStack(spacing: 12) {
                socialButton(
                    icon: "apple.logo",
                    title: "Continue with Apple",
                    action: { authVM.appleAuthManager.startSignInWithAppleFlow() }
                )
                
                socialButton(
                    icon: "globe",
                    title: "Continue with Google",
                    customIcon: Image("google_logo"),
                    action: { authVM.googleAuthManager.signIn() }
                )
            }
        }
    }
    
    // MARK: - Verification Section
    private var verificationSection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showVerificationView = false
                        verificationCode = ""
                        formOffset = 30
                        contentOpacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            formOffset = 0
                            contentOpacity = 1
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                Text("Check your email")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("We sent a verification code to\n\(email)")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Verification code input
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)
                    
                    ZStack(alignment: .leading) {
                        if verificationCode.isEmpty {
                            Text("Verification code")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 16))
                        }
                        
                        TextField("", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                
                Button(action: verifyCode) {
                    Text("Verify & Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(verificationCode.isEmpty)
                .opacity(verificationCode.isEmpty ? 0.6 : 1.0)
            }
        }
    }
    
    // MARK: - Profile Completion Section
    private var profileCompletionSection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button(action: {
                    // Reset all authentication state and go back to email login
                    authVM.logout(context: modelContext)
                    email = ""
                    verificationCode = ""
                    firstName = ""
                    lastName = ""
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showProfileCompletion = false
                        showVerificationView = false
                        formOffset = 30
                        contentOpacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            formOffset = 0
                            contentOpacity = 1
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                Text("Complete your profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Help us personalize your experience")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Profile form inputs
            VStack(spacing: 16) {
                // First Name
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        
                        ZStack(alignment: .leading) {
                            if firstName.isEmpty {
                                Text("First name")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $firstName)
                                .autocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // Last Name
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 20)
                        
                        ZStack(alignment: .leading) {
                            if lastName.isEmpty {
                                Text("Last name")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $lastName)
                                .autocapitalization(.words)
                                .autocorrectionDisabled(true)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                Button(action: updateProfile) {
                    Text("Complete Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(firstName.isEmpty || lastName.isEmpty)
                .opacity(firstName.isEmpty || lastName.isEmpty ? 0.6 : 1.0)
            }
        }
    }
    
    // MARK: - Social Button
    private func socialButton(
        icon: String? = nil,
        title: String,
        customIcon: Image? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let customIcon = customIcon {
                    customIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Error message
            if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Terms and Privacy
            HStack(spacing: 8) {
                Link("Terms", destination: URL(string: "https://example.com/terms")!)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("•")
                    .foregroundColor(.white.opacity(0.4))
                
                Link("Privacy", destination: URL(string: "https://example.com/privacy")!)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Animation Functions
    private func animateEntrance() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
            logoScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            contentOpacity = 1.0
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            formOffset = 0
        }
    }
    
    // MARK: - Action Functions
    private func requestAuthCode() {
        isRequestingCode = true
        authVM.requestAuthCode(email: email) { result in
            isRequestingCode = false
            switch result {
            case .success:
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showVerificationView = true
                    formOffset = -30
                    contentOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        formOffset = 0
                        contentOpacity = 1
                    }
                }
            case .failure(let error):
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    errorMessage = error.localizedDescription
                }
                
                // Auto-hide error after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    private func verifyCode() {
        authVM.verifyCode(email: email, code: verificationCode, context: modelContext) { result in
            switch result {
            case .success(let isProfileComplete):
                if !isProfileComplete {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showProfileCompletion = true
                        showVerificationView = false
                        formOffset = -30
                        contentOpacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            formOffset = 0
                            contentOpacity = 1
                        }
                    }
                } else {
                    // Profile is complete, user will be automatically redirected
                    authVM.isAuthenticated = true
                }
            case .failure(let error):
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    errorMessage = error.localizedDescription
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    private func updateProfile() {
        authVM.updateProfile(firstName: firstName, lastName: lastName) { result in
            switch result {
            case .success:
                authVM.isAuthenticated = true
            case .failure(let error):
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    errorMessage = error.localizedDescription
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    private func setupSocialAuthNotifications() {
        // Handle Apple Sign-In success
        NotificationCenter.default.publisher(for: .appleAuthSuccess)
            .sink { [self] notification in
                guard let userId = notification.userInfo?["userId"] as? String,
                      let firstName = notification.userInfo?["firstName"] as? String,
                      let lastName = notification.userInfo?["lastName"] as? String,
                      let email = notification.userInfo?["email"] as? String else {
                    return
                }
                
                authVM.authenticateWithApple(
                    context: modelContext,
                    userId: userId,
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                ) { result in
                    switch result {
                    case .success(let isProfileComplete):
                        if !isProfileComplete {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showProfileCompletion = true
                                formOffset = -30
                                contentOpacity = 0
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    formOffset = 0
                                    contentOpacity = 1
                                }
                            }
                        }
                    case .failure(let error):
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Handle Google Sign-In success
        NotificationCenter.default.publisher(for: .googleAuthSuccess)
            .sink { [self] notification in
                guard let idToken = notification.userInfo?["idToken"] as? String else {
                    return
                }
                
                authVM.authenticateWithGoogle(
                    context: modelContext,
                    idToken: idToken
                ) { result in
                    switch result {
                    case .success(let isProfileComplete):
                        if !isProfileComplete {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showProfileCompletion = true
                                formOffset = -30
                                contentOpacity = 0
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    formOffset = 0
                                    contentOpacity = 1
                                }
                            }
                        }
                    case .failure(let error):
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Handle authentication failures
        NotificationCenter.default.publisher(for: .appleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .googleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .store(in: &cancellables)
    }
}
