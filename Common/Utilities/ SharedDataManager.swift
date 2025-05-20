import Foundation

struct SharedDataManager {
    static let appGroupID = "group.tech.neocore.MyBrain"
    
    static func saveToken(_ token: String?) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(token, forKey: "accessToken")
        print("SharedDataManager: Token set to: \(token ?? "nil")")
        
    }
    
    static func loadToken() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return nil
        }
        return defaults.string(forKey: "accessToken")
    }
}
