import SwiftUI

class AppStateManager: ObservableObject {
    @Published var hasShownHomeIntro = false
    
    static let shared = AppStateManager()
    
    private init() {}
}
