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
        guard let dateJoinedString = authVM.profileManager.currentProfile?.dateJoined else {
            return "Member since unknown"
        }
        
        if let date = dateJoinedInputFormatter.date(from: dateJoinedString) {
            return "Member since \(memberSinceDateFormatter.string(from: date))"
        }
        
        return "Member since unknown"
    }
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                infoSection
                
                privacyTermsSection
                                
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
                showMenu.toggle()
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
            .overlay(
                VStack {
                    if showMenu {
                        VStack(spacing: 0) {
                            Button(action: {
                                showMenu = false
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
                            
                            Divider()
                                .padding(.horizontal, 8)
                            
                            Button(action: {
                                showMenu = false
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                        .frame(width: 180)
                        .offset(x: -70, y: 50)
                        .zIndex(99999)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMenu)
            )
        }
        .onAppear {
            loadProfileData()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView { image in
                uploadProfileImage(image)
            }
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

// MARK: - Info Section
extension ProfileView {
    private var infoSection: some View {
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
        guard let profile = authVM.profileManager.currentProfile else { return }
        
        editedFirstName = profile.firstName ?? ""
        editedLastName = profile.lastName ?? ""
        editedBirthdate = profile.birthdate ?? ""
        editedGender = authVM.profileManager.getGenderPickerValue()
        
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
        guard let profile = authVM.profileManager.currentProfile else { return }
        
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
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveProfile()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // Form Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Image Section
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
                                    // Handle image picker
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
                            
                            Text("Tap to change profile photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            editField(title: "First Name", text: $editedFirstName)
                            editField(title: "Last Name", text: $editedLastName)
                            
                            // Birthdate Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Birthdate")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    showDatePicker.toggle()
                                }) {
                                    HStack {
                                        Text(dateFormatter.string(from: selectedDate))
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "calendar")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            
                            // Gender Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gender")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Button(action: {
                                    showGenderPicker.toggle()
                                }) {
                                    HStack {
                                        Text(getGenderDisplayText())
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .onAppear {
            loadProfileData()
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .navigationTitle("Select Birthdate")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showDatePicker = false
                            }
                        }
                    }
            }
        }
        .actionSheet(isPresented: $showGenderPicker) {
            ActionSheet(
                title: Text("Select Gender"),
                buttons: [
                    .default(Text("Male")) { editedGender = "M" },
                    .default(Text("Female")) { editedGender = "F" },
                    .default(Text("Other")) { editedGender = "O" },
                    .default(Text("Prefer not to say")) { editedGender = "P" },
                    .cancel()
                ]
            )
        }
    }
    
    private func editField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            TextField(title, text: text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
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
    
    private func getGenderDisplayText() -> String {
        switch editedGender {
        case "M": return "Male"
        case "F": return "Female"
        case "O": return "Other"
        case "P": return "Prefer not to say"
        default: return "Select Gender"
        }
    }
    
    private func saveProfile() {
        authVM.updateProfile(
            firstName: editedFirstName.isEmpty ? "" : editedFirstName,
            lastName: editedLastName.isEmpty ? "" : editedLastName,
            birthdate: dateFormatter.string(from: selectedDate),
            gender: editedGender,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    print("Profile update failed: \(error)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
