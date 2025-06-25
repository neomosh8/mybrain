import Foundation
import SwiftData
import Combine

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var currentProfile: UserProfileData?
    @Published var isProfileLoaded = false
    
    private let networkService = NetworkServiceManager.shared
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
        networkService.profile.updateProfile(
            firstName: firstName,
            lastName: lastName,
            birthdate: birthdate,
            gender: gender
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
}
