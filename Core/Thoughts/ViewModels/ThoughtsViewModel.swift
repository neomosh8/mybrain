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
                    print("WebSocket connected - requesting thoughts list")
                    self?.webSocketService.sendMessage(action: "list_thoughts", data: [:])
                case .failed(let error):
                    self?.errorMessage = "WebSocket connection failed: \(error.localizedDescription)"
                    self?.isLoading = false
                case .disconnected:
                    print("WebSocket disconnected")
                case .connecting:
                    print("WebSocket connecting...")
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
        errorMessage = nil
        
        print("=== Fetching thoughts via WebSocket only ===")
        
        // Connect WebSocket and request thoughts
        webSocketService.connect()
        
        // Add a timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isLoading {
                print("WebSocket thoughts request timed out")
                self.errorMessage = "Request timed out. Please try again."
                self.isLoading = false
            }
        }
    }
    
    func observeWebSocketMessages(onMessageReceived: @escaping ([String: Any]) -> Void) -> AnyCancellable {
        return webSocketService.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { message in
                onMessageReceived(message)
            }
    }
    
    func deleteThought(_ thought: Thought) {
        // Use WebSocket for deletion too
        webSocketService.sendMessage(action: "delete_thought", data: ["thought_id": thought.id])
        
        // Optimistically remove from local array
        thoughts.removeAll { $0.id == thought.id }
    }
    
    func refreshData() {
        print("=== Refreshing thoughts data via WebSocket ===")
        
        // Reset state
        errorMessage = nil
        isLoading = true
        
        // Connect and request fresh data
        webSocketService.connect()
        
        // Small delay to ensure connection is established before sending message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Sending list_thoughts message")
            self.webSocketService.sendMessage(action: "list_thoughts", data: [:])
        }
    }
    
    // MARK: - WebSocket Message Handlers
    private func handleThoughtsList(_ message: [String: Any]) {
        print("=== Handling thoughts_list message ===")
        print("Raw message: \(message)")
        
        guard let data = message["data"] as? [String: Any],
              let thoughtsData = data["thoughts"] as? [[String: Any]] else {
            print("❌ Invalid data format in thoughts_list message")
            print("Message data: \(message["data"] ?? "nil")")
            
            // Check if it's a different format
            if let thoughtsArray = message["data"] as? [[String: Any]] {
                // Data is directly an array
                print("✅ Found thoughts array directly in data")
                let thoughts = thoughtsArray.compactMap { parseThought(from: $0) }
                DispatchQueue.main.async {
                    self.thoughts = thoughts
                    self.isLoading = false
                    self.errorMessage = nil
                }
                return
            }
            
            // If we can't parse, show error
            DispatchQueue.main.async {
                self.errorMessage = "Invalid response format from server"
                self.isLoading = false
            }
            return
        }
        
        var tempThoughts: [Thought] = []
        for thoughtData in thoughtsData {
            if let thought = parseThought(from: thoughtData) {
                tempThoughts.append(thought)
            }
        }
        
        print("✅ Successfully parsed \(tempThoughts.count) thoughts")
        
        DispatchQueue.main.async {
            self.thoughts = tempThoughts
            self.isLoading = false
            self.errorMessage = nil
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
            
            print("✅ Updated thought \(id) status to \(status)")
        }
    }
    
    private func parseThought(from data: [String: Any]) -> Thought? {
        guard let id = data["id"] as? Int,
              let name = data["name"] as? String,
              let content_type = data["content_type"] as? String,
              let status = data["status"] as? String,
              let created_at = data["created_at"] as? String,
              let updated_at = data["updated_at"] as? String else {
            print("❌ Failed to parse thought - missing required fields")
            print("Available fields: \(data.keys)")
            return nil
        }
        
        let description = data["description"] as? String
        let cover = data["cover"] as? String
        let model3D = data["model_3d"] as? String
        
        // DEBUG: Print the cover URL to see what we're getting
        print("📸 Parsing thought '\(name)' with cover URL: '\(cover ?? "nil")'")
        
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
