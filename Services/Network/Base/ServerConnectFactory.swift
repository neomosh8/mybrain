import Foundation
import SwiftData

// MARK: - Server Connect Factory

class ServerConnectFactory {
    private var sharedInstance: ServerConnect?
    var onTokensInvalid: (() -> Void)?
    
    // Create a new ServerConnect instance
    static func makeServerConnect(with modelContext: ModelContext) -> ServerConnect {
        let tokenStorage = SwiftDataTokenStorage(modelContext: modelContext)
        let baseURL = "https://brain.sorenapp.ir"
        let serverConnect = ServerConnect(
            baseURLString: baseURL,
            tokenStorage: tokenStorage
        )
        
        _ = TokenRefreshDecorator(
            decoratedService: serverConnect,
            authService: serverConnect,
            tokenStorage: tokenStorage
        )
        
        return serverConnect
    }
    
    func shared(with modelContext: ModelContext) -> ServerConnect {
        if let existing = sharedInstance {
            return existing
        }
        
        let tokenStorage = SwiftDataTokenStorage(modelContext: modelContext)
        let baseService = ServerConnect(
            baseURLString: "https://brain.sorenapp.ir",
            tokenStorage: tokenStorage
        )
        
        // Create the token refresh decorator
        let tokenRefreshDecorator = TokenRefreshDecorator(
            decoratedService: baseService,
            authService: baseService,
            tokenStorage: tokenStorage
        )
        
        // Set up the force logout callback
        tokenRefreshDecorator.onTokensInvalid = { [weak self] in
            print("Tokens invalid - triggering force logout")
            self?.onTokensInvalid?()
        }
        
        // Create the final decorated service
        let decoratedService = ServerConnect(
            baseURLString: "https://brain.sorenapp.ir",
            tokenStorage: tokenStorage
        )
        
        // You might need to adjust this based on your actual ServerConnect architecture
        // The key is to ensure the TokenRefreshDecorator is in the chain and can trigger logout
        
        sharedInstance = decoratedService
        return decoratedService
    }
    
    func setSharedInstance(_ mockInstance: ServerConnect) {
        sharedInstance = mockInstance
    }
    
    func reset() {
        sharedInstance = nil
    }
}
