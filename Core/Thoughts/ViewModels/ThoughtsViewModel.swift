import SwiftUI
import Combine

class ThoughtsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var thoughts: [Thought] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let networkService = NetworkServiceManager.shared
    private var cancellables = Set<AnyCancellable>()
        
    // MARK: - Public Methods
    
    func fetchThoughts() {
        isLoading = true
        errorMessage = nil
        
        networkService.thoughts.getAllThoughts()
            .sink { result in
                switch result {
                case .success(let thoughts):
                    self.thoughts = thoughts
                    self.isLoading = false
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteThought(_ thought: Thought) {
        networkService.thoughts.archiveThought(thoughtId: thought.id)
            .sink { result in
                switch result {
                case .success:
                    self.thoughts.removeAll { $0.id == thought.id }
                case .failure(let error):
                    self.errorMessage = "Failed to delete thought: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    func retryThought(_ thought: Thought) {
        networkService.thoughts.retryFailedThought(thoughtId: thought.id)
            .sink { result in
                switch result {
                case .success:
                    self.fetchThoughts()
                case .failure(let error):
                    self.errorMessage = "Failed to retry thought: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - WebSocket Methods (for other features that still use WebSocket)
    
    func observeConnectionState(onStateChange: @escaping (WebSocketConnectionState) -> Void) -> AnyCancellable {
        return networkService.webSocket.connectionState
            .receive(on: DispatchQueue.main)
            .sink { state in
                onStateChange(state)
            }
    }
    
    func observeWebSocketMessages(onMessageReceived: @escaping (WebSocketMessage) -> Void) -> AnyCancellable {
        return networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { message in
                onMessageReceived(message)
            }
    }
    
    func storeSubscription(_ subscription: AnyCancellable) {
        cancellables.insert(subscription)
    }
}


extension ThoughtsViewModel {
    func setMockData(_ mockThoughts: [Thought]) {
        self.thoughts = mockThoughts
        self.isLoading = false
        self.errorMessage = nil
    }
}
