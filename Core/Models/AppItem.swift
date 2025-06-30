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


@Model
final class UserProfileData {
    @Attribute(.unique) var id: String
    var userId: String?
    var email: String?
    var firstName: String?
    var lastName: String?
    var birthdate: String?
    var gender: String?
    var avatarUrl: String?
    var onboarded: Bool
    var isActive: Bool
    var isStaff: Bool
    var lastUpdated: Date
    var dateJoined: Date?

    init(
        id: String = "user_profile_data",
        userId: String? = nil,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        birthdate: String? = nil,
        gender: String? = nil,
        avatarUrl: String? = nil,
        onboarded: Bool = false,
        isActive: Bool = true,
        isStaff: Bool = false,
        lastUpdated: Date = Date(),
        dateJoined:Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.birthdate = birthdate
        self.gender = gender
        self.avatarUrl = avatarUrl
        self.onboarded = onboarded
        self.isActive = isActive
        self.isStaff = isStaff
        self.lastUpdated = lastUpdated
        self.dateJoined = dateJoined
    }
    
    func updateFromUserProfile(_ profile: UserProfile) {
        self.userId = profile.id
        self.email = profile.email
        self.firstName = profile.firstName
        self.lastName = profile.lastName
        self.birthdate = profile.birthdate
        self.gender = profile.gender
        self.avatarUrl = profile.avatarUrl
        self.onboarded = profile.onboarded ?? false
        self.isActive = profile.isActive ?? true
        self.isStaff = profile.isStaff ?? false
        self.lastUpdated = Date()
        self.dateJoined = profile.dateJoined
    }
}
