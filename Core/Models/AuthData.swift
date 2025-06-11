import SwiftData

@Model
final class AuthData {
    @Attribute(.unique) var id: String
    var accessToken: String?
    var refreshToken: String?
    var isLoggedIn: Bool

    init(id: String = "user_auth_data", accessToken: String? = nil, refreshToken: String? = nil, isLoggedIn: Bool = false) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.isLoggedIn = isLoggedIn
    }
}
