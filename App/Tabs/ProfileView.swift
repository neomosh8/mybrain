import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var isEditingAccountDetails = false
    @State private var editedFirstName = ""
    @State private var editedLastName = ""
    @State private var editedBirthdate = ""
    @State private var editedGender = ""
    @State private var selectedDate = Date()
    
    @State private var showingImagePicker = false
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var logoutErrorMessage = ""
    
    @State private var showMenu = false
    @State private var showingEditProfileSheet = false
    
    var onNavigateToHome: (() -> Void)?
    
    init(onNavigateToHome: (() -> Void)? = nil) {
        self.onNavigateToHome = onNavigateToHome
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private let memberSinceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dateJoinedInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
    
    private var memberSinceText: String {
        guard let dateJoinedString = authVM.profileManager.currentProfile?.dateJoined,
              let date = dateJoinedInputFormatter.date(from: dateJoinedString) else {
            return "Member since unknown"
        }
        return "Member since \(memberSinceDateFormatter.string(from: date))"
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProfileHeaderView()
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
            }
            .customNavigationBar(
                title: "Profile",
                onBackTap: {
                    onNavigateToHome?()
                }
            ) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMenu.toggle()
                    }
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            // Popup Menu
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { showMenu = false }
                            showingEditProfileSheet = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 20)
                                Text("Edit Profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        Divider().padding(.horizontal, 8)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { showMenu = false }
                            showingLogoutAlert = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(width: 20)
                                Text("Logout")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .frame(width: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .scaleEffect(x: 1, y: showMenu ? 1 : 0, anchor: .top)
                    .animation(.easeInOut(duration: 0.2), value: showMenu)
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .onAppear {
            loadProfileData()
        }
        .sheet(isPresented: $showingEditProfileSheet) {
            EditProfileView()
        }
        .onTapGesture {
            if showMenu {
                withAnimation {
                    showMenu = false
                }
            }
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Logout Error", isPresented: $showLogoutError) {
            Button("OK") { }
        } message: {
            Text(logoutErrorMessage)
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showingImagePicker = false
    
    private let memberSinceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dateJoinedInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
    
    private var memberSinceText: String {
        guard let dateJoinedString = authVM.profileManager.currentProfile?.dateJoined else {
            return "Member since unknown"
        }
        
        if let date = dateJoinedInputFormatter.date(from: dateJoinedString) {
            return "Member since \(memberSinceDateFormatter.string(from: date))"
        }
        
        return "Member since unknown"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main horizontal stack container
            HStack(spacing: 20) {
                // Left side - Avatar
                avatarSection
                
                // Right side - User info
                userInfoSection
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(
                // Modern glass morphism background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
    
    private var avatarSection: some View {
        Button(action: {
            showingImagePicker = true
        }) {
            ZStack {
                // Avatar background with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                // Avatar image or initials
                if let avatarUrl = authVM.profileManager.currentProfile?.avatarUrl,
                   !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } placeholder: {
                        avatarPlaceholder
                    }
                } else {
                    avatarPlaceholder
                }
                
                // Edit indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    )
                    .offset(x: 26, y: 26)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
            
            Text(getInitials())
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full name with modern typography
            Text(getDisplayName())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Email with subtle styling
            Text(authVM.profileManager.currentProfile?.email ?? "")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Member since with modern badge design
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Text(memberSinceText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Helper functions
    private func getDisplayName() -> String {
        let profile = authVM.profileManager.currentProfile
        let firstName = profile?.firstName ?? ""
        let lastName = profile?.lastName ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        if !fullName.isEmpty {
            return fullName
        }
        
        return profile?.email?.components(separatedBy: "@").first?.capitalized ?? "User"
    }
    
    private func getInitials() -> String {
        let profile = authVM.profileManager.currentProfile
        let firstName = profile?.firstName ?? ""
        let lastName = profile?.lastName ?? ""
        
        if !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased()
        }
        
        if !firstName.isEmpty {
            return String(firstName.prefix(2)).uppercased()
        }
        
        if let email = profile?.email {
            return String(email.prefix(1)).uppercased()
        }
        
        return "U"
    }
}


// MARK: - Helper Views
extension ProfileView {
    private func accountDetailRow(
        title: String,
        value: Binding<String>,
        isEditing: Bool
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if isEditing && title != "Email" {
                    TextField(title, text: value)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                } else {
                    Text(value.wrappedValue)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

}

// MARK: - Helper Functions
extension ProfileView {
    private func loadProfileData() {
        editedFirstName = authVM.profileManager.currentProfile?.firstName ?? ""
        editedLastName = authVM.profileManager.currentProfile?.lastName ?? ""
        editedBirthdate = authVM.profileManager.currentProfile?.birthdate ?? ""
        editedGender = authVM.profileManager.currentProfile?.gender ?? ""
        
        if let birthdateString = authVM.profileManager.currentProfile?.birthdate,
           let date = dateFormatter.date(from: birthdateString) {
            selectedDate = date
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditingAccountDetails = false
            loadProfileData() // Reset to original values
        }
    }
    
    private func saveProfile() {
        guard authVM.profileManager.currentProfile != nil else { return }
        
        authVM.updateProfile(
            firstName: editedFirstName.isEmpty ? "" : editedFirstName,
            lastName: editedLastName.isEmpty ? "" : editedLastName,
            birthdate: editedBirthdate.isEmpty ? "" : editedBirthdate,
            gender: editedGender.isEmpty ? nil : editedGender,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isEditingAccountDetails = false
                    }
                case .failure(let error):
                    print("Error updating profile: \(error)")
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        authVM.profileManager.uploadAvatar(
            imageData: imageData,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Profile image updated successfully")
                case .failure(let error):
                    print("Error uploading profile image: \(error)")
                }
            }
        }
    }
    
    private func performLogout() {
        isLoggingOut = true
        
        authVM.logout(context: modelContext) { result in
            DispatchQueue.main.async {
                isLoggingOut = false
                
                switch result {
                case .success:
                    print("Logout successful")
                case .failure(let error):
                    logoutErrorMessage = error.localizedDescription
                    showLogoutError = true
                }
            }
        }
    }
}

// MARK: - Edit Profile Sheet View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var editedFirstName = ""
    @State private var editedLastName = ""
    @State private var editedBirthdate = ""
    @State private var editedGender = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var showGenderPicker = false
    @State private var showAvatarActionSheet = false
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUpdatingAvatar = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveProfile()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.secondary.opacity(0.3))
                
                // Form Content
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                if authVM.profileManager.hasAvatar,
                                   let avatarURL = authVM.profileManager.avatarURL {
                                    AsyncImage(url: avatarURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        if isUpdatingAvatar {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(1.2)
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 100))
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                    }
                                } else {
                                    if isUpdatingAvatar {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(1.2)
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 100))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                }
                                
                                // camera overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            showAvatarActionSheet = true
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 36, height: 36)
                                                    .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 3)
                                                
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .disabled(isUpdatingAvatar)
                                        .opacity(isUpdatingAvatar ? 0.6 : 1.0)
                                    }
                                }
                                .frame(width: 120, height: 120)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Profile Photo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 20) {
                            modernTextField(title: "First Name", text: $editedFirstName, icon: "person")
                            modernTextField(title: "Last Name", text: $editedLastName, icon: "person.badge.plus")
                            
                            // Birthdate Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Birthdate")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showDatePicker.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .frame(width: 20)
                                        
                                        Text(editedBirthdate.isEmpty ? "Select birthdate" : dateFormatter.string(from: selectedDate))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(editedBirthdate.isEmpty ? .secondary.opacity(0.6) : .primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.secondary.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Gender Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gender")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showGenderPicker.toggle()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "person.2")
                                            .foregroundColor(.secondary.opacity(0.7))
                                            .frame(width: 20)
                                        
                                        Text(getGenderDisplayText())
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(editedGender.isEmpty ? .secondary.opacity(0.6) : .primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.secondary.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 60)
                    }
                }
                
                // Date Picker
                if showDatePicker {
                    Color.clear
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showDatePicker = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Select Birthdate")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showDatePicker = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Circle().fill(Color.gray.opacity(0.2)))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 20
                                )
                                .fill(Color(.systemGray6))
                            )
                            
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(WheelDatePickerStyle())
                                .colorScheme(.light)
                                .accentColor(.blue)
                                .onChange(of: selectedDate) { _, newValue in
                                    editedBirthdate = serverDateFormatter.string(from: newValue)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground).opacity(0.95))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
                
                // Gender Picker
                if showGenderPicker {
                    Color.clear
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showGenderPicker = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Select Gender")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showGenderPicker = false
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Circle().fill(Color.gray.opacity(0.2)))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 20
                                )
                                .fill(Color(.systemGray6))
                            )
                            
                            ForEach([
                                ("M", "Male"),
                                ("F", "Female"),
                                ("O", "Other"),
                                ("P", "Prefer not to say")
                            ], id: \.0) { value, label in
                                Button(action: {
                                    editedGender = value
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showGenderPicker = false
                                    }
                                }) {
                                    HStack {
                                        Text(label)
                                            .foregroundColor(.primary)
                                            .font(.system(size: 16))
                                        
                                        Spacer()
                                        
                                        if editedGender == value {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(
                                        Color.blue.opacity(editedGender == value ? 0.1 : 0.0)
                                    )
                                }
                                
                                if value != "P" {
                                    Divider()
                                        .background(Color.secondary.opacity(0.2))
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground).opacity(0.95))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            loadProfileData()
        }
        // Avatar Action Sheet
        .confirmationDialog("Change Profile Photo", isPresented: $showAvatarActionSheet, titleVisibility: .visible) {
            Button("Camera") {
                imagePickerSourceType = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            if authVM.profileManager.hasAvatar {
                Button("Remove Photo", role: .destructive) {
                    removeAvatar()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how you'd like to update your profile photo")
        }
        // Image Picker
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imagePickerSourceType) { image in
                uploadProfileImage(image)
            }
        }
    }
    
    // MARK: - Text Field Component
    private func modernTextField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20)
                
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text("Enter \(title.lowercased())")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 16))
                    }
                    
                    TextField("", text: text)
                        .autocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helper Functions
    private func loadProfileData() {
        editedFirstName = authVM.profileManager.currentProfile?.firstName ?? ""
        editedLastName = authVM.profileManager.currentProfile?.lastName ?? ""
        editedBirthdate = authVM.profileManager.currentProfile?.birthdate ?? ""
        editedGender = authVM.profileManager.currentProfile?.gender ?? ""
        
        if let birthdateString = authVM.profileManager.currentProfile?.birthdate,
           let date = serverDateFormatter.date(from: birthdateString) {
            selectedDate = date
        }
    }
    
    private func getGenderDisplayText() -> String {
        switch editedGender {
        case "M": return "Male"
        case "F": return "Female"
        case "O": return "Other"
        case "P": return "Prefer not to say"
        default: return "Select gender"
        }
    }
    
    private func saveProfile() {
        authVM.updateProfile(
            firstName: editedFirstName.isEmpty ? "" : editedFirstName,
            lastName: editedLastName.isEmpty ? "" : editedLastName,
            birthdate: editedBirthdate.isEmpty ? "" : editedBirthdate,
            gender: editedGender.isEmpty ? nil : editedGender,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dismiss()
                    }
                case .failure(let error):
                    print("Error updating profile: \(error)")
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUpdatingAvatar = true
        
        authVM.profileManager.uploadAvatar(
            imageData: imageData,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                isUpdatingAvatar = false
                switch result {
                case .success:
                    print("Profile image updated successfully")
                case .failure(let error):
                    print("Error uploading profile image: \(error)")
                }
            }
        }
    }
    
    private func removeAvatar() {
        isUpdatingAvatar = true
        
        authVM.profileManager.deleteAvatar(context: modelContext) { result in
            DispatchQueue.main.async {
                isUpdatingAvatar = false
                switch result {
                case .success:
                    print("Profile image removed successfully")
                case .failure(let error):
                    print("Error removing profile image: \(error)")
                }
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ProfileHeaderView()
        .environmentObject(AuthViewModel())
        .padding()
}
