import SwiftUI
import Combine

// MARK: - Settings Manager
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Content Preferences
    @AppStorage("defaultContentMode") var defaultContentMode: String = ContentMode.reading.rawValue
    @AppStorage("signalQualityThreshold") var signalQualityThreshold: Double = 75
    @AppStorage("leadOffDetection") var leadOffDetection: Bool = true
    @AppStorage("autoReconnection") var autoReconnection: Bool = true

    // MARK: - App Behavior
    @AppStorage("pushNotifications") var pushNotifications: Bool = true
    @AppStorage("backgroundAudio") var backgroundAudio: Bool = true
    @AppStorage("appearanceMode") var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("appLanguage") var language: String = "English (US)"

    // MARK: - Computed Properties
    var contentMode: ContentMode {
        get { ContentMode(rawValue: defaultContentMode) ?? .reading }
        set { defaultContentMode = newValue.rawValue }
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceMode) ?? .system }
        set {
            appearanceMode = newValue.rawValue
            applyAppearance(newValue)
        }
    }

    private init() {
        applyAppearance(appearance)
    }

    // MARK: - Appearance Management
    func applyAppearance(_ mode: AppearanceMode) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }
            
            switch mode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}
