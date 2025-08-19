import Foundation
import SwiftUICore

// MARK: - Main Tab

enum TabItem: Int, CaseIterable {
    case home = 0
    case profile = 1
    case device = 2
    case settings = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .profile: return "Profile"
        case .device: return "Device"
        case .settings: return "Settings"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .profile: return "person"
        case .device: return ""
        case .settings: return "gearshape"
        }
    }
}


// MARK: - Home Tab

enum ContentMode: String, CaseIterable {
    case reading = "reading"
    case listening = "listening"
    
    var title: String {
        switch self {
        case .reading: return "Reading"
        case .listening: return "Listening"
        }
    }
    
    var icon: String {
        switch self {
        case .reading: return "eye"
        case .listening: return "headphones"
        }
    }
}


// MARK: - Profile Tab

struct InsightItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

struct TrendItem: Identifiable {
    let id = UUID()
    let percentage: Int
    let label: String
    let change: String
    let color: Color
}

struct ThoughtItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let score: Int
    let scoreType: String
    let progress: Double
    let color: Color
}


// MARK: - Device Tab

enum OnboardingState {
    case welcome
    case scanning
    case connecting
    case permissionIssue
}

enum CardState {
    case connectingToSaved(deviceName: String)
    case tapToConnect
    case connected(deviceInfo: DeviceInfo)
    case connectionFailed
}

struct DeviceInfo {
    let name: String
    let serialNumber: String?
    let batteryLevel: Int?
}
