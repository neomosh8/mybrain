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

// MARK: - Content Mode Enum
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
