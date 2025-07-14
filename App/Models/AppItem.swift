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
    var dateJoined: String?

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
        dateJoined: String? = nil
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
        if let userId = profile.id {
            self.userId = userId
        }
        
        if let email = profile.email, !email.isEmpty {
            self.email = email
        }
        
        if let firstName = profile.firstName, !firstName.isEmpty {
            self.firstName = firstName
        }
        
        if let lastName = profile.lastName, !lastName.isEmpty {
            self.lastName = lastName
        }
        
        if let birthdate = profile.birthdate {
            self.birthdate = birthdate
        }
        
        if let gender = profile.gender, !gender.isEmpty {
            self.gender = gender
        }
        
        if let avatarUrl = profile.avatarUrl {
            self.avatarUrl = avatarUrl
        }
        
        if let onboarded = profile.onboarded {
            self.onboarded = onboarded
        }
        
        if let isActive = profile.isActive {
            self.isActive = isActive
        }
        
        if let isStaff = profile.isStaff {
            self.isStaff = isStaff
        }
        
        if let dateJoined = profile.dateJoined {
            self.dateJoined = dateJoined
        }
        
        self.lastUpdated = Date()
    }
    
    // MARK: - Computed Properties
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return email ?? "User"
    }
    
    var genderDisplay: String {
        guard let gender = gender else { return "Not set" }
        
        switch gender.uppercased() {
        case "M":
            return "Male"
        case "F":
            return "Female"
        case "N":
            return "Non-binary"
        case "O":
            return "Other"
        case "P":
            return "Prefer not to say"
        default:
            return "Not set"
        }
    }
    
    var isProfileCompleteBasic: Bool {
        return !(firstName?.isEmpty ?? true) &&
               !(lastName?.isEmpty ?? true) &&
               !(email?.isEmpty ?? true)
    }
}
