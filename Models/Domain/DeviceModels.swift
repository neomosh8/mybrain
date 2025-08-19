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
