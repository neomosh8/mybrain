import Foundation
import UIKit
import SwiftData
import Combine

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var currentProfile: UserProfileData?
    @Published var isProfileLoaded = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Profile Loading
    
    func loadProfileFromStorage(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<UserProfileData>(
            predicate: #Predicate { $0.id == "user_profile_data" }
        )
        
        do {
            if let profile = try context.fetch(fetchDescriptor).first {
                self.currentProfile = profile
                self.isProfileLoaded = true
            }
        } catch {
            print("Error loading profile from storage: \(error)")
        }
    }
    
    func fetchProfileFromServer(context: ModelContext) {
        networkService.profile.getProfile()
            .sink { result in
                switch result {
                case .success(let userProfile):
                    self.saveProfile(userProfile, context: context)
                case .failure(let error):
                    print("Error fetching profile: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Profile Saving
    
    func saveProfile(_ userProfile: UserProfile, context: ModelContext) {
        let oldAvatarUrl = currentProfile?.avatarUrl
        let newAvatarUrl = userProfile.avatarUrl
        
        // Call the original saveProfile method
        let fetchDescriptor = FetchDescriptor<UserProfileData>(
            predicate: #Predicate { $0.id == "user_profile_data" }
        )
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            let profileData = existing.first ?? UserProfileData()
            
            profileData.updateFromUserProfile(userProfile)
            
            if existing.isEmpty {
                context.insert(profileData)
            }
            
            try context.save()
            self.currentProfile = profileData
            self.isProfileLoaded = true
            
            // Handle avatar cache update if URL changed
            if oldAvatarUrl != newAvatarUrl {
                AvatarImageCache.shared.updateAvatarCache(with: newAvatarUrl)
            }
            
        } catch {
            print("Error saving profile: \(error)")
        }
    }
    
    // MARK: - Profile Updates
    
    func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        birthdate: String? = nil,
        gender: String? = nil,
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        let serverGender = convertGenderToShortFormat(gender)
        
        networkService.profile.updateProfile(
            firstName: firstName,
            lastName: lastName,
            birthdate: birthdate,
            gender: serverGender
        )
        .sink { result in
            switch result {
            case .success(let userProfile):
                self.saveProfile(userProfile, context: context)
                completion(.success(userProfile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        .store(in: &cancellables)
    }
    
    func uploadAvatar(
        imageData: Data,
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        networkService.profile.uploadAvatar(imageData: imageData)
            .sink { result in
                switch result {
                case .success(let userProfile):
                    self.saveProfile(userProfile, context: context)
                    completion(.success(userProfile))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteAvatar(
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        networkService.profile.deleteAvatar()
            .sink { result in
                switch result {
                case .success(let userProfile):
                    self.saveProfile(userProfile, context: context)
                    completion(.success(userProfile))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Profile Access Methods
    
    var fullName: String {
        guard let profile = currentProfile else { return "" }
        let firstName = profile.firstName ?? ""
        let lastName = profile.lastName ?? ""
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return currentProfile?.email ?? "User"
    }
    
    var hasAvatar: Bool {
        currentProfile?.avatarUrl != nil && !(currentProfile?.avatarUrl?.isEmpty ?? true)
    }
    
    var avatarURL: URL? {
        guard let urlString = currentProfile?.avatarUrl else { return nil }
        return URL(string: urlString)
    }
    
    // MARK: - Gender Conversion Methods
    
    /// Convert full gender name to short format for server storage
    private func convertGenderToShortFormat(_ gender: String?) -> String? {
        guard let gender = gender, !gender.isEmpty else { return nil }
        
        switch gender.lowercased() {
        case "male":
            return "M"
        case "female":
            return "F"
        case "non-binary":
            return "N"
        case "other":
            return "O"
        case "prefer not to say", "":
            return "P"
        default:
            // If it's already in short format, return as is
            if ["M", "F", "N", "O", "P"].contains(gender.uppercased()) {
                return gender.uppercased()
            }
            return "P" // Default to "Prefer not to say"
        }
    }
    
    /// Convert short gender format to display format
    func getGenderDisplayName(_ shortGender: String?) -> String {
        guard let shortGender = shortGender else { return "Not set" }
        
        switch shortGender.uppercased() {
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
    
    /// Get the full gender name for the picker
    func getGenderPickerValue() -> String {
        guard let gender = currentProfile?.gender else { return "" }
        return convertShortGenderToFullName(gender)
    }
    
    private func convertShortGenderToFullName(_ shortGender: String) -> String {
        switch shortGender.uppercased() {
        case "M":
            return "male"
        case "F":
            return "female"
        case "N":
            return "non-binary"
        case "O":
            return "other"
        case "P", "":
            return ""
        default:
            return ""
        }
    }
    
    // MARK: - Clear Profile
    
    func clearProfile(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<UserProfileData>(
            predicate: #Predicate { $0.id == "user_profile_data" }
        )
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            if let profile = existing.first {
                context.delete(profile)
                try context.save()
            }
            
            self.currentProfile = nil
            self.isProfileLoaded = false
            
        } catch {
            print("Error clearing profile: \(error)")
        }
    }
    
    
    /// Enhanced upload avatar with cache management
    func uploadAvatarWithCache(
        imageData: Data,
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        networkService.profile.uploadAvatar(imageData: imageData)
            .sink { result in
                switch result {
                case .success(let userProfile):
                    self.saveProfile(userProfile, context: context)
                    
                    // Pre-cache the uploaded image
                    if let avatarUrl = userProfile.avatarUrl,
                       let image = UIImage(data: imageData) {
                        AvatarImageCache.shared.setImage(image, for: avatarUrl)
                    }
                    
                    completion(.success(userProfile))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    /// Enhanced delete avatar with cache management
    func deleteAvatarWithCache(
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        networkService.profile.deleteAvatar()
            .sink { result in
                switch result {
                case .success(let userProfile):
                    self.saveProfile(userProfile, context: context)
                    
                    // Clear avatar cache
                    AvatarImageCache.shared.updateAvatarCache(with: nil)
                    
                    completion(.success(userProfile))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteAccount(
        context: ModelContext,
        completion: @escaping (Result<DeleteAccountResponse, Error>) -> Void
    ) {
        networkService.profile.deleteAccount()
            .sink { result in
                switch result {
                case .success(let response):
                    self.clearProfile(context: context)
                    completion(.success(response))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }

}
