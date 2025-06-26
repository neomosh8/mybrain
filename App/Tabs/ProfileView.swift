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
    
    private var memberSinceText: String {
        guard let dateJoined = authVM.profileManager.currentProfile?.dateJoined else {
            return "Member since unknown"
        }
        return "Member since \(memberSinceDateFormatter.string(from: dateJoined))"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                accountDetailsSection
                
                privacyTermsSection
                
                logoutSection
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadProfileData()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { image in
                uploadProfileImage(image)
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

// MARK: - Header Section
extension ProfileView {
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if authVM.profileManager.hasAvatar,
                   let avatarURL = authVM.profileManager.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: "camera")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 30, y: 30)
            }
            
        VStack(spacing: 4) {
                Text(authVM.profileManager.displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(authVM.profileManager.currentProfile?.email ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(memberSinceText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Account Details Section
extension ProfileView {
    private var accountDetailsSection: some View {
        VStack(spacing: 16) {
            // Section Header with Edit Button
            HStack {
                Text("Account Details")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isEditingAccountDetails {
                    // Save and Cancel buttons
                    HStack(spacing: 12) {
                        Button(action: cancelEditing) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                        }
                        
                        Button(action: saveProfile) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    }
                } else {
                    Button(action: startEditing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                    }
                }
            }
            
            VStack(spacing: 12) {
                // First Name
                accountDetailRow(
                    title: "First Name",
                    value: isEditingAccountDetails ? $editedFirstName : .constant(authVM.profileManager.currentProfile?.firstName ?? ""),
                    isEditing: isEditingAccountDetails
                )
                
                Divider().padding(.leading, 16)
                
                // Last Name
                accountDetailRow(
                    title: "Last Name",
                    value: isEditingAccountDetails ? $editedLastName : .constant(authVM.profileManager.currentProfile?.lastName ?? ""),
                    isEditing: isEditingAccountDetails
                )
                
                Divider().padding(.leading, 16)
                
                // Birthdate
                if isEditingAccountDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birthdate")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .onChange(of: selectedDate) { _, newValue in
                                editedBirthdate = dateFormatter.string(from: newValue)
                            }
                    }
                    .padding(.horizontal, 16)
                } else {
                    accountDetailRow(
                        title: "Birthdate",
                        value: .constant(authVM.profileManager.currentProfile?.birthdate ?? "Not set"),
                        isEditing: false
                    )
                }
                
                Divider().padding(.leading, 16)
                
                // Gender
                if isEditingAccountDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Picker("Gender", selection: $editedGender) {
                            Text("Prefer not to say").tag("")
                            Text("Male").tag("male")
                            Text("Female").tag("female")
                            Text("Non-binary").tag("non-binary")
                            Text("Other").tag("other")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 16)
                } else {
                    accountDetailRow(
                        title: "Gender",
                        value: .constant(authVM.profileManager.currentProfile?.gender?.capitalized ?? "Not set"),
                        isEditing: false
                    )
                }
                
                Divider().padding(.leading, 16)
                
                // Email (not editable)
                accountDetailRow(
                    title: "Email",
                    value: .constant(authVM.profileManager.currentProfile?.email ?? ""),
                    isEditing: false
                )
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Privacy and Terms Section
extension ProfileView {
    private var privacyTermsSection: some View {
        VStack(spacing: 12) {
            actionRow(
                icon: "doc.text",
                title: "Terms of Service",
                subtitle: "Read our terms and conditions",
                iconColor: .blue
            ) {
                openURL("https://neocore.com/terms")
            }
            
            actionRow(
                icon: "shield",
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                iconColor: .green
            ) {
                openURL("https://neocore.com/privacy")
            }
        }
    }
}

// MARK: - Logout Section
extension ProfileView {
    private var logoutSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingLogoutAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logout")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                        
                        Text("Sign out of your account")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(isLoggingOut)
        }
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
    
    private func actionRow(
        icon: String,
        title: String,
        subtitle: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Functions
extension ProfileView {
    private func loadProfileData() {
        // Load initial values for editing
        editedFirstName = authVM.profileManager.currentProfile?.firstName ?? ""
        editedLastName = authVM.profileManager.currentProfile?.lastName ?? ""
        editedBirthdate = authVM.profileManager.currentProfile?.birthdate ?? ""
        editedGender = authVM.profileManager.currentProfile?.gender ?? ""
        
        if let birthdateString = authVM.profileManager.currentProfile?.birthdate,
           let date = dateFormatter.date(from: birthdateString) {
            selectedDate = date
        }
    }
    
    private func startEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditingAccountDetails = true
        }
    }
    
    private func cancelEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditingAccountDetails = false
            loadProfileData() // Reset to original values
        }
    }
    
    private func saveProfile() {
        authVM.profileManager.updateProfile(
            firstName: editedFirstName.isEmpty ? nil : editedFirstName,
            lastName: editedLastName.isEmpty ? nil : editedLastName,
            birthdate: editedBirthdate.isEmpty ? nil : editedBirthdate,
            gender: editedGender.isEmpty ? nil : editedGender,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isEditingAccountDetails = false
                    }
                case .failure(let error):
                    print("Error updating profile: \(error)")
                    // Show error alert if needed
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
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Image Picker
struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
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
    NavigationStack {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
