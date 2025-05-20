// Core/Thoughts/ViewModels/ThoughtsViewModel.swift

import SwiftUI
import Combine

class ThoughtsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var thoughts: [Thought] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let thoughtService: ThoughtNetworkService
    private let webSocketService: WebSocketService & ThoughtWebSocketService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        thoughtService: ThoughtNetworkService,
        webSocketService: WebSocketService & ThoughtWebSocketService
    ) {
        self.thoughtService = thoughtService
        self.webSocketService = webSocketService
        
        webSocketService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if let type = message["type"] as? String {
                    switch type {
                    case "thoughts_list":
                        self?.handleThoughtsList(message)
                    case "thought_update":
                        self?.handleThoughtUpdate(message)
                    default:
                        break
                    }
                }
            }
            .store(in: &cancellables)
        
        webSocketService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.webSocketService
                        .sendMessage(action: "list_thoughts", data: [:])
                case .failed(let error):
                    self?.errorMessage = "WebSocket connection failed: \(error.localizedDescription)"
                    self?.isLoading = false
                case .disconnected:
                    break
                case .connecting:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func observeConnectionState(onStateChange: @escaping (WebSocketConnectionState) -> Void) -> AnyCancellable {
        return webSocketService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { state in
                onStateChange(state)
            }
    }
    
    func storeSubscription(_ subscription: AnyCancellable) {
        cancellables.insert(subscription)
    }
    
    func getWebSocketService() -> WebSocketService & ThoughtWebSocketService {
        return webSocketService
    }
    
    func fetchThoughts() {
        isLoading = true
        
        thoughtService.fetchThoughts()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                    self?.isLoading = false
                },
                receiveValue: { [weak self] thoughts in
                    self?.thoughts = thoughts
                }
            )
            .store(in: &cancellables)
        
        webSocketService.connect()
    }
    
    func observeWebSocketMessages(onMessageReceived: @escaping ([String: Any]) -> Void) -> AnyCancellable {
        return webSocketService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { message in
                onMessageReceived(message)
            }
    }
    
    func deleteThought(_ thought: Thought) {
        thoughtService.deleteThought(id: thought.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.thoughts.removeAll { $0.id == thought.id }
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshData() {
        fetchThoughts()
        webSocketService.sendMessage(action: "list_thoughts", data: [:])
    }
    
    // MARK: - WebSocket Message Handlers
    private func handleThoughtsList(_ message: [String: Any]) {
        guard let data = message["data"] as? [String: Any],
              let thoughtsData = data["thoughts"] as? [[String: Any]] else {
            print("Invalid data format in thoughts_list message")
            return
        }
        
        var tempThoughts: [Thought] = []
        for thoughtData in thoughtsData {
            if let thought = parseThought(from: thoughtData) {
                tempThoughts.append(thought)
            }
        }
        
        DispatchQueue.main.async {
            self.thoughts = tempThoughts
            self.isLoading = false
        }
    }
    
    private func handleThoughtUpdate(_ message: [String: Any]) {
        guard let data = message["data"] as? [String: Any],
              let thoughtData = data["thought"] as? [String: Any],
              let id = thoughtData["id"] as? Int,
              let status = thoughtData["status"] as? String else {
            print("Invalid data format in thought_update message")
            return
        }
        
        if let index = thoughts.firstIndex(where: { $0.id == id }) {
            var updatedThought = thoughts[index]
            updatedThought.status = status
            
            DispatchQueue.main.async {
                var tempThoughts = self.thoughts
                tempThoughts[index] = updatedThought
                self.thoughts = tempThoughts
            }
        }
    }
    
    private func parseThought(from data: [String: Any]) -> Thought? {
        guard let id = data["id"] as? Int,
              let name = data["name"] as? String,
              let content_type = data["content_type"] as? String,
              let status = data["status"] as? String,
              let created_at = data["created_at"] as? String,
              let updated_at = data["updated_at"] as? String else {
            return nil
        }
        
        let description = data["description"] as? String
        let cover = data["cover"] as? String
        let model3D = data["model_3d"] as? String
        
        return Thought(
            id: id,
            name: name,
            description: description,
            content_type: content_type,
            cover: cover,
            status: status,
            created_at: created_at,
            updated_at: updated_at,
            model_3d: model3D
        )
    }
}
