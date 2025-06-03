struct AuthCodeRequest: Codable {
    let email: String
}

struct VerifyCodeRequest: Codable {
    let email: String
    let code: String
    let device_info: DeviceInfo
}

struct TokenResponse: Codable {
    let access: String
    let refresh: String
    let profileComplete: Bool
}

struct ErrorResponse: Codable {
    let detail: String
}

struct DeviceInfo: Codable {
    let device_name: String
    let os_name: String
    let app_version: String
    let unique_number: String
}



struct RegisterResponse: Codable {
    let detail: String
}
