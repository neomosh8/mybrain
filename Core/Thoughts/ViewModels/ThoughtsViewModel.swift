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
    
    // MARK: - Initialization
    init() {
    }
    
    // MARK: - Public Methods
    
    func fetchThoughts() {
        isLoading = true
        errorMessage = nil
        
        
        networkService.thoughts.getAllThoughts()
            .sink { result in
                switch result {
                case .success(let thoughts):
                    print("✅ Successfully fetched \(thoughts.count) thoughts")
                    self.thoughts = thoughts
                    self.isLoading = false
                    self.errorMessage = nil
                case .failure(let error):
                    print("❌ Failed to fetch thoughts: \(error)")
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
                    print("✅ Successfully deleted thought: \(thought.name)")
                    // Remove from local array
                    self.thoughts.removeAll { $0.id == thought.id }
                case .failure(let error):
                    print("❌ Failed to delete thought: \(error)")
                    self.errorMessage = "Failed to delete thought: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshData() {
        print("=== Refreshing thoughts data ===")
        fetchThoughts()
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
