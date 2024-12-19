struct RegisterRequest: Codable {
    let email: String
    let first_name: String
    let last_name: String
}

struct RegisterResponse: Codable {
    let detail: String
}

struct VerifyRequest: Codable {
    let email: String
    let code: String
    let device_info: DeviceInfo
}

struct LoginRequest: Codable {
    let email: String
}

struct VerifyLoginRequest: Codable {
    let email: String
    let code: String
    let device_info: DeviceInfo
}

struct TokenResponse: Codable {
    let access: String
    let refresh: String
}

struct ErrorResponse: Codable {
    let detail: String
}

// Example DeviceInfo (you can customize values)
struct DeviceInfo: Codable {
    let device_name: String
    let os_name: String
    let app_version: String
    let unique_number: String
}
