import Foundation
import SwiftData

// MARK: - Server Connect Factory

class ServerConnectFactory {
    private var sharedInstance: ServerConnect?
    
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
        let baseURL = "https://brain.sorenapp.ir"
        let serverConnect = ServerConnect(
            baseURLString: baseURL,
            tokenStorage: tokenStorage
        )
        
        sharedInstance = serverConnect
        return serverConnect
    }
    
    func setSharedInstance(_ mockInstance: ServerConnect) {
        sharedInstance = mockInstance
    }
    
    func resetSharedInstance() {
        sharedInstance = nil
    }
}
