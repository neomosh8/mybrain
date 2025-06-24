import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var userStats = UserStats(
        thoughtsConsumed: 47,
        totalUsage: "156h",
        avgPerformance: 84,
        dayStreak: 12
    )
    
    @State private var userPreferences = UserPreferences(
        defaultReadingSpeed: 250,
        pushNotifications: true,
        dataSharing: false,
        autoResume: true
    )
    
    @State private var showingPasswordChange = false
    @State private var showingExportData = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDeleteAccount = false
    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var logoutErrorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Account Details
                    accountDetailsSection
                    
                    // Your Stats
                    statsSection
                    
                    // Preferences
                    preferencesSection
                    
                    // Account Actions
                    accountActionsSection
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingPasswordChange) {
            ChangePasswordView()
        }
        .sheet(isPresented: $showingExportData) {
            ExportDataView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently removed.")
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
            // Profile Picture
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                if let profileURL = authVM.googleAuthManager.profilePictureURL {
                    AsyncImage(url: profileURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                
                // Edit button overlay
                Button(action: {
                    // Handle profile picture change
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "camera")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .offset(x: 25, y: 25)
            }
            
            // Name and Email
            VStack(spacing: 4) {
                Text("\(authVM.googleAuthManager.firstName ?? "Sarah") \(authVM.googleAuthManager.lastName ?? "Johnson")")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(authVM.googleAuthManager.email ?? "sarah.johnson@email.com")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("Member since March 2024")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Account Details Section
extension ProfileView {
    private var accountDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Details")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                profileDetailRow(
                    title: "First Name",
                    value: authVM.googleAuthManager.firstName ?? "Sarah",
                    showDivider: true
                )
                
                profileDetailRow(
                    title: "Last Name",
                    value: authVM.googleAuthManager.lastName ?? "Johnson",
                    showDivider: true
                )
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email Address")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Text(authVM.googleAuthManager.email ?? "sarah.johnson@email.com")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                
                                Text("Verified")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    
    private func profileDetailRow(title: String, value: String, showDivider: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Text(value)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Handle edit action
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Stats Section
extension ProfileView {
    private var statsSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Text("Your Stats")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    statCard(
                        value: "\(userStats.thoughtsConsumed)",
                        label: "Thoughts Consumed",
                        color: .blue
                    )
                    
                    statCard(
                        value: userStats.totalUsage,
                        label: "Total Usage",
                        color: .green
                    )
                }
                
                HStack(spacing: 0) {
                    statCard(
                        value: "\(userStats.avgPerformance)%",
                        label: "Avg Performance",
                        color: .purple
                    )
                    
                    statCard(
                        value: "\(userStats.dayStreak)",
                        label: "Day Streak",
                        color: .red
                    )
                }
            }
            .padding(16)
            .background(Color(.systemIndigo).opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
    }
}

// MARK: - Preferences Section
extension ProfileView {
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                preferenceRow(
                    title: "Default Reading Speed",
                    subtitle: "\(userPreferences.defaultReadingSpeed) words per minute",
                    action: .disclosure,
                    actionHandler: {
                        // Handle reading speed change
                    }
                )
                
                Divider().padding(.leading, 16)
                
                preferenceRow(
                    title: "Push Notifications",
                    subtitle: "Daily reminders and achievements",
                    action: .toggle(userPreferences.pushNotifications),
                    actionHandler: {
                        userPreferences.pushNotifications.toggle()
                    }
                )
                
                Divider().padding(.leading, 16)
                
                preferenceRow(
                    title: "Data Sharing",
                    subtitle: "Anonymous usage analytics",
                    action: .toggle(userPreferences.dataSharing),
                    actionHandler: {
                        userPreferences.dataSharing.toggle()
                    }
                )
                
                Divider().padding(.leading, 16)
                
                preferenceRow(
                    title: "Auto-Resume",
                    subtitle: "Continue where you left off",
                    action: .toggle(userPreferences.autoResume),
                    actionHandler: {
                        userPreferences.autoResume.toggle()
                    }
                )
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Account Actions Section
extension ProfileView {
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            accountActionRow(
                icon: "key",
                title: "Change Password",
                subtitle: "Update your security credentials",
                iconColor: .blue
            ) {
                showingPasswordChange = true
            }
            
            accountActionRow(
                icon: "arrow.down.doc",
                title: "Export Data",
                subtitle: "Download your personal information",
                iconColor: .green
            ) {
                showingExportData = true
            }
            
            accountActionRow(
                icon: "shield",
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                iconColor: .indigo
            ) {
                showingPrivacyPolicy = true
            }
            
            accountActionRow(
                icon: "trash",
                title: "Delete Account",
                subtitle: "Permanently remove your account",
                iconColor: .red
            ) {
                showingDeleteAccount = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    private func accountActionRow(
        icon: String,
        title: String,
        subtitle: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
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

// MARK: - Preference Row Helper
extension ProfileView {
    enum PreferenceAction {
        case toggle(Bool)
        case disclosure
    }
    
    private func preferenceRow(
        title: String,
        subtitle: String,
        action: PreferenceAction,
        actionHandler: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            switch action {
            case .toggle(let isOn):
                Toggle("", isOn: .constant(isOn))
                    .labelsHidden()
                    .onTapGesture {
                        actionHandler()
                    }
                
            case .disclosure:
                Button(action: actionHandler) {
                    HStack(spacing: 4) {
                        Text("Change")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if case .toggle(_) = action {
                actionHandler()
            }
        }
    }
}

// MARK: - Helper Functions
extension ProfileView {
    private func saveProfile() {
        // Save profile changes to server/local storage
        print("Saving profile changes...")
    }
    
    private func deleteAccount() {
        // Handle account deletion
        print("Deleting account...")
    }
}

// MARK: - Data Models
struct UserStats {
    var thoughtsConsumed: Int
    var totalUsage: String
    var avgPerformance: Int
    var dayStreak: Int
}

struct UserPreferences {
    var defaultReadingSpeed: Int
    var pushNotifications: Bool
    var dataSharing: Bool
    var autoResume: Bool
}

// MARK: - Supporting Views
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Change Password")
                    .font(.title2)
                    .padding()
                
                // Password change form would go here
                
                Spacer()
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Export Data")
                    .font(.title2)
                    .padding()
                
                // Data export options would go here
                
                Spacer()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .padding()
                    
                    Text("How we protect your data...")
                        .padding(.horizontal)
                    
                    // Privacy policy content would go here
                    
                    Spacer()
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
