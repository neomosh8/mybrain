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
    @State private var showSubtitles = true
    @State private var audioQuality: AudioQuality = .high
    @State private var autoPlayNextChapter = false
    @State private var storeBiometricData = true
    @State private var shareAnalyticsData = true
    @State private var dataRetentionPeriod: DataRetention = .oneYear
    @State private var pushNotifications = true
    @State private var backgroundAudio = true
    @State private var appearance: AppearanceMode = .light
    @State private var language = "English (US)"
    
    enum ContentMode: String, CaseIterable {
        case reading = "Reading"
        case listening = "Listening"
    }
    
    enum AudioQuality: String, CaseIterable {
        case high = "High (320kbps)"
        case standard = "Standard (192kbps)"
        case low = "Low (128kbps)"
    }
    
    enum DataRetention: String, CaseIterable {
        case thirtyDays = "30 days"
        case ninetyDays = "90 days"
        case oneYear = "1 year"
        case forever = "Forever"
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
                privacyDataSection
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
            
            // Show Subtitles Toggle
            SettingsToggleRow(
                title: "Show Subtitles",
                subtitle: "Display text during audio playback",
                isOn: $showSubtitles
            )
            
            // Audio Quality
            SettingsPickerRow(
                title: "Audio Quality",
                selection: audioQuality.rawValue
            ) {
                // Audio quality picker action
            }
            
            // Auto-play Next Chapter Toggle
            SettingsToggleRow(
                title: "Auto-play Next Chapter",
                subtitle: "Continue to next chapter automatically",
                isOn: $autoPlayNextChapter
            )
        }
    }
}

// MARK: - Privacy & Data Section
extension SettingsView {
    private var privacyDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "hand.raised.fill",
                title: "Privacy & Data",
                iconColor: .purple
            )
            
            // Store Biometric Data Toggle
            SettingsToggleRow(
                title: "Store Biometric Data",
                subtitle: "Save EEG data for analysis",
                isOn: $storeBiometricData
            )
            
            // Share Analytics Data Toggle
            SettingsToggleRow(
                title: "Share Analytics Data",
                subtitle: "Help improve the app experience",
                isOn: $shareAnalyticsData
            )
            
            // Export Performance Data
            ActionRow(
                icon: "square.and.arrow.down",
                title: "Export Performance Data",
                subtitle: "Download your data as CSV",
                iconColor: .blue
            ) {
                exportPerformanceData()
            }
            
            // Data Retention Period
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Retention Period")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    ForEach(DataRetention.allCases, id: \.self) { period in
                        HStack {
                            Button(action: {
                                dataRetentionPeriod = period
                            }) {
                                HStack {
                                    Image(systemName: dataRetentionPeriod == period ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(.blue)
                                    Text(period.rawValue)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
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
            SettingsToggleRow(
                title: "Push Notifications",
                subtitle: "Session reminders and updates",
                isOn: $pushNotifications
            )
            
            // Background Audio Toggle
            SettingsToggleRow(
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
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "info.circle.fill",
                title: "Support & Information",
                iconColor: .blue
            )
            
            ActionRow(
                icon: "questionmark.circle",
                title: "Help & Documentation",
                iconColor: .blue
            ) {
                openURL("https://neocore.com/help")
            }
            
            ActionRow(
                icon: "message.circle",
                title: "Contact Support",
                iconColor: .green
            ) {
                openURL("mailto:support@neocore.com")
            }
            
            ActionRow(
                icon: "doc.text",
                title: "Terms & Privacy",
                iconColor: .purple
            ) {
                openURL("https://neocore.com/terms")
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

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}

struct SettingsPickerRow: View {
    let title: String
    let selection: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(selection)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Functions
extension SettingsView {
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func exportPerformanceData() {
        // Implement CSV export functionality
        print("Exporting performance data...")
    }
}

#Preview {
    SettingsView()
}
