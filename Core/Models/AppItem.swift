import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

@Model
final class AuthData {
    @Attribute(.unique) var id: String
    var accessToken: String?
    var refreshToken: String?
    var isLoggedIn: Bool
    var profileComplete: Bool

    init(id: String = "user_auth_data", accessToken: String? = nil, refreshToken: String? = nil, isLoggedIn: Bool = false, profileComplete: Bool = false) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.isLoggedIn = isLoggedIn
        self.profileComplete = profileComplete
    }
}
