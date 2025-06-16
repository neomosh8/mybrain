import Foundation
import Combine

/*
 Usage Example:
 
 class SomeViewModel: ObservableObject {
     private var cancellables = Set<AnyCancellable>()
     private let networkService = NetworkServiceManager.shared
     
     @Published var thoughts: [Thought] = []
     @Published var isLoading = false
     @Published var errorMessage: String?
     
     func loadThoughts() {
         isLoading = true
         errorMessage = nil
         
         networkService.thoughts.getAllThoughts()
             .receive(on: DispatchQueue.main)
             .sink { [weak self] result in
                 self?.isLoading = false
                 
                 switch result {
                 case .success(let thoughts):
                     self?.thoughts = thoughts
                 case .failure(let error):
                     self?.errorMessage = error.localizedDescription
                 }
             }
             .store(in: &cancellables)
     }
     
     func authenticateWithEmail(_ email: String, code: String) {
         networkService.auth.verifyAuthCode(
             email: email,
             code: code,
             deviceInfo: DeviceInfo.current
         )
         .receive(on: DispatchQueue.main)
         .sink { result in
             switch result {
             case .success(let tokenResponse):
                 print("Authentication successful")
                 // Navigate to main app
             case .failure(let error):
                 print("Authentication failed: \(error)")
             }
         }
         .store(in: &cancellables)
     }
     
     func connectWebSocket() {
         networkService.webSocket.openSocket()
         
         networkService.webSocket.activateReceiveMessage { message in
             // Handle incoming WebSocket messages
             print("Received WebSocket message: \(message)")
         }
         
         // Send a message
         networkService.webSocket.sendStreamingLinks(thoughtId: 123)
     }
 }
 */
