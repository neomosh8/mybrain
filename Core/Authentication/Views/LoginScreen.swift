import SwiftUI
import Combine

struct GenderOption: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

struct LoginScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthdate = Date()
    @State private var selectedGender = ""
    
    @State private var showDatePicker = false
    @State private var showGenderPicker = false
    @State private var tempBirthdate = Date()
    @State private var birthdateSelected = false
    
    @State private var genderOptions = [
        GenderOption(value: "", label: "Select Gender"),
        GenderOption(value: "M", label: "Male"),
        GenderOption(value: "F", label: "Female"),
        GenderOption(value: "P", label: "Prefer not to say"),
        GenderOption(value: "O", label: "Other")
    ]
        
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
                    Spacer(minLength: 40)
                    
                    // Header section
                    VStack(spacing: 20) {
                        // Logo with glow effect
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 110, height: 110)
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
                    authVM.logout(context: modelContext) { result in
                        switch result {
                        case .success:
                            print("Logout successful")
                        case .failure(let error):
                            print("Logout failed: \(error)")
                        }
                    }
                    
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
            
            VStack(spacing: 8) {
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
                
                // Last Name
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
                
                // MARK: - Birthdate Selection
                VStack(spacing: 0) {
                    // Birthdate trigger button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showDatePicker.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            Text(birthdateSelected ?
                                 DateFormatter.displayFormatter.string(from: birthdate) :
                                 "Select birthdate")
                                .foregroundColor(birthdateSelected ? .white : .white.opacity(0.5))
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 12))
                                .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showDatePicker)
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
                    
                    // Date Picker Overlay
                    if showDatePicker {
                        VStack(spacing: 0) {
                            DatePicker("", selection: $birthdate, displayedComponents: .date)
                                .datePickerStyle(WheelDatePickerStyle())
                                .colorScheme(.dark) // Ensures proper text color in dark theme
                                .accentColor(.blue) // Sets selection color
                                .onChange(of: birthdate) { _, newValue in
                                    birthdateSelected = true
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            
                            // Done button for date picker
                            Button("Done") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showDatePicker = false
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.05))
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(1) // Ensures overlay appears above other elements
                    }
                }
                
                // MARK: - Gender Selection
                VStack(spacing: 0) {
                    // Gender trigger button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showGenderPicker.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            Text(genderOptions.first(where: { $0.value == selectedGender })?.label ?? "Select Gender")
                                .foregroundColor(selectedGender.isEmpty ? .white.opacity(0.5) : .white)
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 12))
                                .rotationEffect(.degrees(showGenderPicker ? 180 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showGenderPicker)
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
                    
                    // Gender Picker Overlay
                    if showGenderPicker {
                        VStack(spacing: 0) {
                            ForEach(genderOptions.dropFirst()) { option in // Skip the first "Select Gender" option
                                Button(action: {
                                    selectedGender = option.value
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showGenderPicker = false
                                    }
                                }) {
                                    HStack {
                                        Text(option.label)
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                        
                                        Spacer()
                                        
                                        if selectedGender == option.value {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(
                                        Color.white.opacity(selectedGender == option.value ? 0.1 : 0.05)
                                    )
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(1) // Ensures overlay appears above other elements
                    }
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
        print("🚀 Starting profile update...")
        print("📝 First Name: '\(firstName)'")
        print("📝 Last Name: '\(lastName)'")
        print("📅 Birthdate selected: \(birthdateSelected)")
        print("📅 Birthdate value: \(birthdate)")
        print("👤 Selected Gender: '\(selectedGender)'")
        
        // Convert birthdate to API format if selected
        let birthdateString: String? = birthdateSelected ? DateFormatter.apiFormatter.string(from: birthdate) : nil
        print("📅 Birthdate string for API: \(birthdateString ?? "nil")")
        
        // Only send gender if one was actually selected
        let genderValue = selectedGender.isEmpty ? nil : selectedGender
        print("👤 Gender value for API: \(genderValue ?? "nil")")
        
        print("🌐 Calling authVM.updateProfile...")
        
        authVM.updateProfile(
            firstName: firstName,
            lastName: lastName,
            birthdate: birthdateString,
            gender: genderValue,
            context: modelContext
        ) { result in
            print("📡 Received response from authVM.updateProfile")
            
            switch result {
            case .success(let userProfile):
                print("✅ Profile updated successfully!")
                print("👤 User Profile: \(userProfile)")
                authVM.isAuthenticated = true
            case .failure(let error):
                print("❌ Profile update failed!")
                print("🔍 Error: \(error)")
                print("🔍 Error description: \(error.localizedDescription)")
                
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
                guard let userId = notification.userInfo?["userId"] as? String else {
                    return
                }
                
                let firstName = notification.userInfo?["firstName"] as? String
                let lastName = notification.userInfo?["lastName"] as? String
                let email = notification.userInfo?["email"] as? String
                
                self.authVM.authenticateWithApple(
                    context: self.modelContext,
                    userId: userId,
                    firstName: firstName,
                    lastName: lastName,
                    email: email
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let isProfileComplete):
                            if !isProfileComplete {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.showProfileCompletion = true
                                    self.formOffset = -30
                                    self.contentOpacity = 0
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.formOffset = 0
                                        self.contentOpacity = 1
                                    }
                                }
                            }
                        case .failure(let error):
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                self.errorMessage = error.localizedDescription
                            }
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
                                
                self.authVM.authenticateWithGoogle(
                    context: self.modelContext,
                    idToken: idToken
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let isProfileComplete):
                            if !isProfileComplete {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    self.showProfileCompletion = true
                                    self.formOffset = -30
                                    self.contentOpacity = 0
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        self.formOffset = 0
                                        self.contentOpacity = 1
                                    }
                                }
                            }
                        case .failure(let error):
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                self.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Handle authentication failures
        NotificationCenter.default.publisher(for: .appleAuthFailure)
            .sink { [self] notification in
                if let error = notification.userInfo?["error"] as? Error {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .googleAuthFailure)
            .sink { [self] notification in                if let error = notification.userInfo?["error"] as? Error {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}

extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let apiFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
