import SwiftUI
import Combine

class ThoughtsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var thoughts: [Thought] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    init() {
        setupWebSocketConnection()
        fetchThoughts()
    }
    
    private func setupWebSocketConnection() {
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    func fetchThoughts() {
        isLoading = true
        errorMessage = nil
        
        networkService.thoughts.getAllThoughts()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.isLoading = false
                
                switch result {
                case .success(let thoughts):
                    self?.thoughts = thoughts
                    self?.errorMessage = nil
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
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
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .connectionResponse(let status, let message, let data):
            if status.isSuccess {
                print("WebSocket connection confirmed: \(message)")
                if let responseData = ConnectionResponseData(from: data) {
                    print("Welcome user: \(responseData.user ?? "Unknown")")
                }
            } else {
                print("WebSocket connection failed: \(message)")
            }
            
        case .thoughtUpdate(let status, let message, let data):
            if status.isSuccess,
               let thoughtUpdateData = ThoughtUpdateData(from: data) {
                updateThought(with: thoughtUpdateData.thought)
            } else {
                print("Thought update error: \(message)")
            }
            
        case .thoughtStatus(let status, let message, let data):
            if status.isSuccess, let data = data,
               let thoughtData = ThoughtData(from: data) {
                updateThought(with: thoughtData)
            } else {
                print("Failed to get thought status: \(message)")
            }
            
        default:
            break
        }
    }
    
    func refreshThoughtStatus(thoughtId: String) {
        networkService.webSocket.requestThoughtStatus(thoughtId: thoughtId)
    }
    
    private func updateThought(with thoughtData: ThoughtData) {
        guard let index = thoughts.firstIndex(where: { $0.id == thoughtData.id }) else { return }
        
        let currentThought = thoughts[index]
        let updatedThought = Thought(
            id: thoughtData.id,
            name: thoughtData.name,
            description: currentThought.description,
            contentType: currentThought.contentType,
            cover: thoughtData.cover,
            model3d: thoughtData.model3d,
            status: thoughtData.status,
            progress: thoughtData.progress ?? currentThought.progress,
            createdAt: thoughtData.createdAt,
            updatedAt: thoughtData.updatedAt
        ).withProcessedURLs()
        
        thoughts[index] = updatedThought
        
        print("Updated thought: \(updatedThought.name) - Status: \(updatedThought.status) - Progress: \(updatedThought.progress.completed)/\(updatedThought.progress.total)")
    }
    
    deinit {
        networkService.webSocket.closeSocket()
    }
}


extension ThoughtsViewModel {
    func setMockData(_ mockThoughts: [Thought]) {
        self.thoughts = mockThoughts
        self.isLoading = false
        self.errorMessage = nil
    }
}
