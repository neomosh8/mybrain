import Foundation
import SwiftData

// MARK: - Token Storage with SwiftData

class SwiftDataTokenStorage: TokenStorage {
    private let modelContext: ModelContext
    private let userDefaultsStorage: UserDefaultsTokenStorage
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.userDefaultsStorage = UserDefaultsTokenStorage()
    }
    
    func saveTokens(accessToken: String, refreshToken: String) {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            let authData = existing.first ?? AuthData()
            
            authData.accessToken = accessToken
            authData.refreshToken = refreshToken
            authData.isLoggedIn = true
            
            if existing.isEmpty {
                modelContext.insert(authData)
            }
            
            try modelContext.save()
            
            userDefaultsStorage
                .saveTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            
        } catch {
            print(
                "Error saving tokens to SwiftData: \(error.localizedDescription)"
            )
        }
    }
    
    func getAccessToken() -> String? {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            return existing.first?.accessToken
        } catch {
            print(
                "Error fetching access token from SwiftData: \(error.localizedDescription)"
            )
            return userDefaultsStorage
                .getAccessToken() // Try to retrieve from UserDefaults
        }
    }
    
    func getRefreshToken() -> String? {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            return existing.first?.refreshToken
        } catch {
            print(
                "Error fetching refresh token from SwiftData: \(error.localizedDescription)"
            )
            return userDefaultsStorage
                .getRefreshToken() // Try to retrieve from UserDefaults
        }
    }
    
    func clearTokens() {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        
        do {
            let existing = try modelContext.fetch(fetchDescriptor)
            if let authData = existing.first {
                authData.accessToken = nil
                authData.refreshToken = nil
                authData.isLoggedIn = false
                try modelContext.save()
            }
            
            userDefaultsStorage.clearTokens()
            
        } catch {
            print(
                "Error clearing tokens from SwiftData: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - UserDefaults Token Storage (for Share Extension)

class UserDefaultsTokenStorage: TokenStorage {
    private let appGroupID = "group.tech.neocore.MyBrain" // App Group ID
    
    func saveTokens(accessToken: String, refreshToken: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        defaults.set(accessToken, forKey: "accessToken")
        defaults.set(refreshToken, forKey: "refreshToken")
        defaults.set(true, forKey: "isLoggedIn")
        defaults.synchronize()
        
        SharedDataManager.saveToken(accessToken)
    }
    
    func getAccessToken() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return nil
        }
        return defaults.string(forKey: "accessToken")
    }
    
    func getRefreshToken() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return nil
        }
        return defaults.string(forKey: "refreshToken")
    }
    
    func clearTokens() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        
        defaults.removeObject(forKey: "accessToken")
        defaults.removeObject(forKey: "refreshToken")
        defaults.set(false, forKey: "isLoggedIn")
        defaults.synchronize()
        
        SharedDataManager.saveToken(nil)
    }
}
