import SwiftUI
import Combine
import SwiftData

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var isAuthenticated = false
    @Published var isProfileComplete: Bool = false
    @Published var profileManager = ProfileManager.shared

    @Published var appleAuthManager = AppleAuthManager()
    @Published var googleAuthManager = GoogleAuthManager()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkServiceManager.shared
    
    // MARK: - Initialization
    
    init() {
        setupAppleAuthNotifications()
        setupGoogleAuthNotifications()
    }
    
    // MARK: - Private Methods
    
    private func setupAppleAuthNotifications() {
        NotificationCenter.default.publisher(for: .appleAuthSuccess)
            .sink { notification in
                      if let firstName = notification.userInfo?["firstName"] as? String,
                         let lastName = notification.userInfo?["lastName"] as? String {
                          print("Apple auth successful for \(firstName) \(lastName)")
                      }
                  }
                  .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .appleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    print("Apple Sign-In failed: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupGoogleAuthNotifications() {
        NotificationCenter.default.publisher(for: .googleAuthSuccess)
            .sink { _ in
                print("Google auth successful with token")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .googleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    print("Google Sign-In failed: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadFromSwiftData(context: ModelContext) {
        print("Loading auth data from SwiftData...")
        
        // Load auth data
        let authFetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data" })
        
        do {
            let authResults = try context.fetch(authFetchDescriptor)
            if let authData = authResults.first {
                self.accessToken = authData.accessToken
                self.refreshToken = authData.refreshToken
                self.isAuthenticated = authData.isLoggedIn
                self.isProfileComplete = authData.profileComplete
                
                print("Auth data loaded - isAuthenticated: \(self.isAuthenticated), isProfileComplete: \(self.isProfileComplete)")
                print("Tokens present: access=\(authData.accessToken != nil), refresh=\(authData.refreshToken != nil)")
            } else {
                print("No auth data found in SwiftData")
                self.isAuthenticated = false
                self.isProfileComplete = false
            }
        } catch {
            print("Error loading auth data: \(error)")
            self.isAuthenticated = false
            self.isProfileComplete = false
        }
        
        // Load profile data
        profileManager.loadProfileFromStorage(context: context)
        
        // Validate authentication state
        validateAuthenticationState(context: context)
    }

    private func validateAuthenticationState(context: ModelContext) {
        // If we have tokens but no profile data, check if we need to complete profile
        if isAuthenticated, let profile = profileManager.currentProfile {
            let hasRequiredFields = !(profile.firstName?.isEmpty ?? true) &&
                                  !(profile.lastName?.isEmpty ?? true)
            
            if !hasRequiredFields {
                print("Profile incomplete - missing required fields")
                self.isProfileComplete = false
                updateProfileCompleteInSwiftData(context: context, isComplete: false)
            }
        } else if isAuthenticated && profileManager.currentProfile == nil {
            print("Authenticated but no profile data found")
            // Don't change isProfileComplete here - rely on server response
        }
    }

    func requestAuthCode(
        email: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        networkService.auth.requestAuthCode(email: email)
            .sink { result in
                switch result {
                case .success(let response):
                    completion(.success(response.detail))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            .store(in: &cancellables)
    }
    
    func verifyCode(
        email: String,
        code: String,
        context: ModelContext,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        networkService.auth.verifyAuthCode(
            email: email,
            code: code,
            deviceInfo: DeviceInfo.current
        )
        .sink { result in
            switch result {
            case .success(let tokenResponse):
                self.handleSuccessfulAuth(tokenResponse: tokenResponse, context: context)
                completion(.success(tokenResponse.profileComplete))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        .store(in: &cancellables)
    }
    
    func updateProfile(
        firstName: String,
        lastName: String,
        birthdate: String? = nil,
        gender: String? = nil,
        context: ModelContext,
        completion: @escaping (Result<UserProfile, Error>) -> Void
    ) {
        profileManager.updateProfile(
            firstName: firstName,
            lastName: lastName,
            birthdate: birthdate,
            gender: gender,
            context: context
        ) { result in
            switch result {
            case .success(let userProfile):
                self.isProfileComplete = true
                self.updateProfileCompleteInSwiftData(context: context, isComplete: true)
                completion(.success(userProfile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func logout(
        context: ModelContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let refreshToken = self.refreshToken else {
            performLocalLogout(context: context)
            completion(.success(()))
            return
        }
        
        networkService.auth.logout(
            refreshToken: refreshToken,
            deviceId: DeviceInfo.current.uniqueNumber
        )
        .sink { result in
            switch result {
            case .success:
                self.performLocalLogout(context: context)
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        .store(in: &cancellables)
    }
    
    func authenticateWithApple(
        context: ModelContext,
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        networkService.auth.appleLogin(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            email: email,
            deviceInfo: DeviceInfo.current
        )
        .sink { result in
            switch result {
            case .success(let tokenResponse):
                self.handleSuccessfulAuth(tokenResponse: tokenResponse, context: context)
                completion(.success(tokenResponse.profileComplete))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        .store(in: &cancellables)
    }
    
    func authenticateWithGoogle(
        context: ModelContext,
        idToken: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        networkService.auth.googleLogin(
            idToken: idToken,
            deviceInfo: DeviceInfo.current
        )
        .sink { result in
            switch result {
            case .success(let tokenResponse):
                self.handleSuccessfulAuth(tokenResponse: tokenResponse, context: context)
                completion(.success(tokenResponse.profileComplete))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    private func handleSuccessfulAuth(tokenResponse: TokenResponse, context: ModelContext) {
        print("Handling successful auth...")
        
        self.accessToken = tokenResponse.access
        self.refreshToken = tokenResponse.refresh
        self.isAuthenticated = true
        self.isProfileComplete = tokenResponse.profileComplete
        
        SharedDataManager.saveToken(tokenResponse.access)
        
        // Save profile data from server response FIRST
        if let profile = tokenResponse.profile {
            profileManager.saveProfile(profile, context: context)
            print("Profile data saved from auth response")
        }
        
        // Then save auth data
        saveToSwiftData(context: context)
        
        // Fetch full profile if needed
        if tokenResponse.profileComplete {
            profileManager.fetchProfileFromServer(context: context)
        }
        
        print("Auth completed - isProfileComplete: \(tokenResponse.profileComplete)")
    }
    
    private func saveToSwiftData(context: ModelContext) {
        print("Attempting to save auth data to SwiftData...")
        
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data" })
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            let authData: AuthData
            
            if let existingData = existing.first {
                authData = existingData
                print("Updating existing auth data")
            } else {
                authData = AuthData()
                context.insert(authData)
                print("Creating new auth data")
            }
            
            authData.accessToken = self.accessToken
            authData.refreshToken = self.refreshToken
            authData.isLoggedIn = self.isAuthenticated
            authData.profileComplete = self.isProfileComplete
            

            try context.save()
            print("Auth data saved successfully - isAuthenticated: \(self.isAuthenticated), isProfileComplete: \(self.isProfileComplete)")
            
        } catch {
            print("Error saving auth data: \(error)")
        }
    }
    
    private func updateProfileCompleteInSwiftData(context: ModelContext, isComplete: Bool) {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data" })
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            if let authData = existing.first {
                authData.profileComplete = isComplete
                try context.save()
            }
        } catch {
            print("Error updating profile complete status: \(error)")
        }
    }
    
    private func performLocalLogout(context: ModelContext) {
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
        self.isProfileComplete = false
        
        SharedDataManager.saveToken(nil)
        clearFromSwiftData(context: context)
        
        profileManager.clearProfile(context: context)
    }
    
    private func clearFromSwiftData(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data" })
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            if let authData = existing.first {
                authData.accessToken = nil
                authData.refreshToken = nil
                authData.isLoggedIn = false
                authData.profileComplete = false
                try context.save()
            }
        } catch {
            print("Error clearing auth data: \(error)")
        }
    }
}

extension AuthViewModel {
    /// Force logout when tokens are invalid/expired
    func forceLogout(context: ModelContext) {
        print("Force logout due to invalid tokens")
        performLocalLogout(context: context)
        print("Force logout completed - user will see login screen")
    }
}
