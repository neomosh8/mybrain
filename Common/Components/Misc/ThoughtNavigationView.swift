import SwiftUI
import Combine

/**
 A reusable container that:
 1) Fetches the status of a Thought on appear
 2) If the Thought is "in_progress" or "finished," prompts user to Resume or Restart
 3) Handles the reset_reading logic if user chooses "Restart"
 4) Calls back to the parent with onResume / onResetFinished
 5) Always uses a custom overlay instead of iOS confirmation dialogs
 */
struct ThoughtNavigationView<Content: View>: View {
    let thought: Thought

    private let networkService = NetworkServiceManager.shared

    // The child content to show once user chooses "Resume" or if status is "not_started"
    @ViewBuilder let content: () -> Content
    
    // Internal states
    @State private var thoughtStatus: ThoughtStatus?
    @State private var isFetchingStatus = true
    
    // Show our custom overlay or not
    @State private var showPrompt = false
    
    // For showing "Reset successful" alert
    @State private var showResetSuccess = false
    
    // State property for cancellables
    @State private var cancellables = Set<AnyCancellable>()
    
    // These are user-provided callbacks (injected via .onResume / .onResetFinished)
    var _onResume: (() -> Void)? = nil
    var _onResetFinished: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // If we're still loading the status, just show a ProgressView
            if isFetchingStatus {
                ProgressView("Checking Thought Status...")
            } else {
                // The normal content
                content()
                    .blur(
                        radius: showPrompt ? 3 : 0
                    )  // Blur if prompt is active
                    .onAppear {
                        // If we already know the status is in_progress or finished,
                        // show the prompt. (E.g. navigate away and come back.)
                        presentPromptIfNeeded()
                    }
                
                if showPrompt {
                    resumeRestartOverlay
                }
            }
        }
        .alert(isPresented: $showResetSuccess) {
            Alert(
                title: Text("Success"),
                message: Text("Reading progress reset successfully"),
                dismissButton: .default(Text("Ok"))
            )
        }
        .onAppear {
            fetchThoughtStatus()
        }
        .onDisappear {
            // Clear cancellables
            cancellables = Set<AnyCancellable>()
        }
    }
}

// MARK: - Computed Helpers
extension ThoughtNavigationView {
    private var statusString: String {
        thoughtStatus?.status ?? "not_started"
    }
    
    private var isInProgress: Bool {
        statusString == "in_progress"
    }
    
    private var isFinished: Bool {
        statusString == "finished"
    }
    
    /// Only show the prompt if the server says "in_progress" or "finished"
    private func presentPromptIfNeeded() {
        if isInProgress || isFinished {
            showPrompt = true
        } else {
            showPrompt = false
            resetReading()
        }
    }
}

// MARK: - Fetch Status
extension ThoughtNavigationView {
    private func fetchThoughtStatus() {
        isFetchingStatus = true
        
        // Try HTTP API first, fallback to WebSocket
        networkService.thoughts.getThoughtStatus(thoughtId: thought.id)
            .sink { result in
                switch result {
                case .success(let status):
                    self.isFetchingStatus = false
                    self.thoughtStatus = status
                    self.presentPromptIfNeeded()
                case .failure:
                    // Fallback to WebSocket
                    self.fetchStatusViaWebSocket()
                }
            }
            .store(in: &cancellables)
    }
    
    private func fetchStatusViaWebSocket() {
        // For WebSocket, you'd need to implement a custom message sender
        // Since this isn't in the standard 3 message types
        print("Fetching status via WebSocket - custom implementation needed")
        
        // Subscribe to WebSocket messages for status response
        networkService.webSocket.messages
            .filter { message in
                switch message {
                case .response(let action, _):
                    return action == "thought_chapters"
                default:
                    return false
                }
            }
            .first()
            .sink { message in
                switch message {
                case .response(_, let data):
                    self.isFetchingStatus = false
                    self.handleThoughtStatusResponse(data)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleThoughtStatusResponse(_ data: [String: Any]) {
        guard
            let status = data["status"] as? String, status == "success",
            let responseData = data["data"] as? [String: Any]
        else {
            // Could show an error message
            return
        }
        
        let statusString = responseData["status"] as? String ?? "not_started"
        let thoughtId = responseData["thought_id"] as? Int ?? thought.id
        let thoughtName = responseData["thought_name"] as? String ?? thought.name
        let progressDict = responseData["progress"] as? [String: Any] ?? [:]
        let chaptersArray = responseData["chapters"] as? [[String: Any]] ?? []
        
        let progressData = ThoughtProgress(
            total: progressDict["total"] as? Int ?? 0,
            completed: progressDict["completed"] as? Int ?? 0,
            remaining: progressDict["remaining"] as? Int ?? 0
        )
        
        let chapters = chaptersArray.map { ch -> Chapter in
            Chapter(
                chapterNumber: ch["chapter_number"] as? Int ?? 0,
                title: ch["title"] as? String ?? "",
                content: ch["content"] as? String ?? "",
                status: ch["status"] as? String ?? ""
            )
        }
        
        let newStatus = ThoughtStatus(
            thoughtId: thoughtId,
            thoughtName: thoughtName,
            status: statusString,
            progress: progressData,
            chapters: chapters
        )
        
        self.thoughtStatus = newStatus
        
        // Now that we have the final status, see if we need the resume/restart prompt
        presentPromptIfNeeded()
    }
}

// MARK: - Overlay: Resume / Restart
extension ThoughtNavigationView {
    @ViewBuilder
    private var resumeRestartOverlay: some View {
        VStack(spacing: 16) {
            if isInProgress {
                Text(
                    "It seems you are in the middle of the stream / reading for \(thoughtStatus?.thoughtName ?? thought.name)."
                )
                .font(.headline)
                .padding()
                
                HStack {
                    Button("Restart From Beginning") {
                        resetReading()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Resume") {
                        onResumeChosen()
                    }
                    .buttonStyle(.bordered)
                }
                
            } else if isFinished {
                Text(
                    "It seems you have finished \(thoughtStatus?.thoughtName ?? thought.name)."
                )
                .font(.headline)
                .padding()
                
                Button("Restart From Beginning") {
                    resetReading()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Resume / Reset
extension ThoughtNavigationView {
    private func onResumeChosen() {
        showPrompt = false  // dismiss the overlay
        _onResume?()        // call parent's resume logic
    }
    
    private func resetReading() {
        // Use HTTP API for reset
        networkService.thoughts.resetThoughtProgress(thoughtId: thought.id)
            .sink { result in
                switch result {
                case .success:
                    self.handleResetSuccess()
                case .failure(let error):
                    print("Reset failed: \(error)")
                    // Could show error alert
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleResetSuccess() {
        showPrompt = false
        showResetSuccess = true
        
        // Let the parent know we are done resetting
        _onResetFinished?()
    }
}

// MARK: - Provide a chainable API for .onResume and .onResetFinished
extension ThoughtNavigationView {
    func onResume(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy._onResume = action
        return copy
    }
    
    func onResetFinished(_ action: @escaping () -> Void) -> Self {
        var copy = self
        copy._onResetFinished = action
        return copy
    }
}
