import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onNavigateToHome: (() -> Void)?
    
    init(onNavigateToHome: (() -> Void)? = nil) {
        self.onNavigateToHome = onNavigateToHome
    }
    
    @State private var signalQualityThreshold: Double = 75
    @State private var leadOffDetection = true
    @State private var autoReconnection = true
    @State private var defaultMode: ContentMode = .reading
    @State private var pushNotifications = true
    @State private var backgroundAudio = true
    @State private var appearance: AppearanceMode = .light
    @State private var language = "English (US)"
    
    enum ContentMode: String, CaseIterable {
        case reading = "Reading"
        case listening = "Listening"
    }
        
    enum AppearanceMode: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case auto = "Auto"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                contentPreferencesSection
                appBehaviorSection
                supportInformationSection
                appVersionSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .appNavigationBar(
            title: "Settings",
            subtitle: "App configuration",
            onBackTap: {
                onNavigateToHome?() ?? dismiss()
            }
        ) {
            Button(action: {
                print("More options tapped")
            }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Content Preferences Section
extension SettingsView {
    private var contentPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "textformat.size",
                title: "Content Preferences",
                iconColor: .green
            )
            
            // Default Consumption Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Consumption Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(ContentMode.allCases, id: \.self) { mode in
                        Button(action: {
                            defaultMode = mode
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mode == .reading ? "eye" : "headphones")
                                    .font(.system(size: 14, weight: .medium))
                                Text(mode.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(defaultMode == mode ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(defaultMode == mode ? Color.blue : Color(.systemGray6))
                            )
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - App Behavior Section
extension SettingsView {
    private var appBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "gearshape.fill",
                title: "App Behavior",
                iconColor: .orange
            )
            
            // Push Notifications Toggle
            ToggleRow(
                title: "Push Notifications",
                subtitle: "Session reminders and updates",
                isOn: $pushNotifications
            )
            
            // Background Audio Toggle
            ToggleRow(
                title: "Background Audio",
                subtitle: "Continue playback when app is closed",
                isOn: $backgroundAudio
            )
            
            // Appearance
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button(action: {
                            appearance = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(appearance == mode ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(appearance == mode ? Color.blue : Color(.systemGray5))
                                )
                        }
                    }
                    Spacer()
                }
            }
            
            // Language
            ActionRow(
                icon: "globe",
                title: "Language",
                subtitle: language,
                iconColor: .blue
            ) {
                // Language picker action
            }
        }
    }
}

// MARK: - Support & Information Section
extension SettingsView {
    private var supportInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                icon: "info.circle.fill",
                title: "Support & Information",
                iconColor: .blue
            )
            
            ActionRow(
                icon: "doc.text",
                title: "Terms of Service",
                subtitle: "Read our terms and conditions",
                iconColor: .blue
            ) {
                openURL("https://neocore.com/terms")
            }

            ActionRow(
                icon: "shield",
                title: "Privacy Policy",
                subtitle: "How we protect your data",
                iconColor: .green
            ) {
                openURL("https://neocore.com/privacy")
            }
            
            ActionRow(
                icon: "message",
                title: "Contact Support",
                subtitle: "Contant us via email",
                iconColor: .purple
            ) {
                openURL("mailto:support@neocore.com")
            }
            
        }
    }
}

// MARK: - App Version Section
extension SettingsView {
    private var appVersionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("App Version")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("2.1.4 (Build 240)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Helper Views
struct SectionHeader: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Helper Functions
extension SettingsView {
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
}
