import Foundation
import UIKit

struct PhoneInfo: Codable {
    let deviceName: String
    let osName: String
    let appVersion: String
    let uniqueNumber: String
    
    static var current: PhoneInfo {
        let phoneInfo = PhoneInfo(
            deviceName: UIDevice.current.name,
            osName: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            uniqueNumber: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
        print("🔍 Phone info created: \(phoneInfo)")
        return phoneInfo
    }
}

struct PreferenceItem: Codable {
    let id: String
    let liked: Bool
}
