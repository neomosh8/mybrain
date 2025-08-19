import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager.shared

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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Consumption Mode")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(ContentMode.allCases, id: \.self) { mode in
                        Button(action: {
                            settings.contentMode = mode
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .medium))
                                Text(mode.title)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(settings.contentMode == mode ? .white : Color.label)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(settings.contentMode == mode ?
                                          Color.accentColor : Color.secondarySystemBackground)
                            )
                        }
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var appBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "gearshape.fill",
                title: "App Behavior",
                iconColor: .orange
            )
            
            ToggleRow(
                title: "Push Notifications",
                subtitle: "Session reminders and updates",
                isOn: $settings.pushNotifications
            )
            
            ToggleRow(
                title: "Background Audio",
                subtitle: "Continue playback when app is closed",
                isOn: $settings.backgroundAudio
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button(action: {
                            settings.appearance = mode
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: appearanceIcon(for: mode))
                                    .font(.system(size: 12, weight: .medium))
                                Text(mode.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(settings.appearance == mode ? .white : Color.label)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(settings.appearance == mode ?
                                          Color.accentColor : Color.secondarySystemBackground)
                            )
                        }
                    }
                    Spacer()
                }
            }
            
            ActionRow(
                icon: "globe",
                title: "Language",
                subtitle: settings.language,
                iconColor: .blue
            ) {
                // Language picker action
            }
        }
    }
    
    private func appearanceIcon(for mode: AppearanceMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
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
