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
    private var isWebSocketConnected = false
    
    // MARK: - Public Methods
    
    init() {
        fetchThoughts()
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
                    self?.connectWebSocket()
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
    
    // MARK: - Private Methods
    private func connectWebSocket() {
        guard !isWebSocketConnected else { return }
        
        networkService.webSocket.openSocket()
        
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
        
        networkService.webSocket.connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.isWebSocketConnected = true
                    print("WebSocket connected successfully")
                case .disconnected, .failed(_):
                    self?.isWebSocketConnected = false
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .response(let action, let data):
            switch action {
            case "thought_update":
                handleThoughtUpdate(data: data)
            case "connection":
                print("WebSocket connection confirmed")
            default:
                break
            }
        default:
            break
        }
    }
    
    
    private func handleThoughtUpdate(data: [String: Any]) {
        guard let thoughtData = data["thought"] as? [String: Any],
              let thoughtId = thoughtData["id"] as? String else {
            print("Invalid thought update data")
            return
        }
        
        if let index = thoughts.firstIndex(where: { $0.id == thoughtId }) {
            updateThought(at: index, with: thoughtData)
        }
    }
    
    private func updateThought(at index: Int, with data: [String: Any]) {
        let currentThought = thoughts[index]
        
        let updatedThought = Thought(
            id: currentThought.id,
            name: data["name"] as? String ?? currentThought.name,
            description: data["description"] as? String ?? currentThought.description,
            contentType: data["content_type"] as? String ?? currentThought.contentType,
            cover: data["cover"] as? String ?? currentThought.cover,
            model3d: data["model_3d"] as? String ?? currentThought.model3d,
            status: data["status"] as? String ?? currentThought.status,
            progress: parseProgress(from: data) ?? currentThought.progress,
            createdAt: data["created_at"] as? String ?? currentThought.createdAt,
            updatedAt: data["updated_at"] as? String ?? currentThought.updatedAt
        ).withProcessedURLs()
        
        thoughts[index] = updatedThought
        
        print("Updated thought: \(updatedThought.name) - Status: \(updatedThought.status)")
    }
    
    private func parseProgress(from data: [String: Any]) -> ThoughtProgress? {
        guard let progressData = data["progress"] as? [String: Any],
              let total = progressData["total"] as? Int,
              let completed = progressData["completed"] as? Int,
              let remaining = progressData["remaining"] as? Int else {
            return nil
        }
        
        return ThoughtProgress(total: total, completed: completed, remaining: remaining)
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
