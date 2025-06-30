import Foundation
import UIKit

struct DeviceInfo: Codable {
    let deviceName: String
    let osName: String
    let appVersion: String
    let uniqueNumber: String
    
    static var current: DeviceInfo {
        let deviceInfo = DeviceInfo(
            deviceName: UIDevice.current.name,
            osName: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            uniqueNumber: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        )
        print("🔍 Device info created: \(deviceInfo)")
        return deviceInfo
    }
}

struct PreferenceItem: Codable {
    let id: String
    let liked: Bool
}
