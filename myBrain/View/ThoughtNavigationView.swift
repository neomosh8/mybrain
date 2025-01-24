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
    @ObservedObject var socketViewModel: WebSocketViewModel
    
    // The child content to show once user chooses “Resume” or if status is "not_started"
    @ViewBuilder let content: () -> Content
    
    // Internal states
    @State private var thoughtStatus: ThoughtStatus?
    @State private var isFetchingStatus = true
    
    // Show our custom overlay or not
    @State private var showPrompt = false
    
    // For showing "Reset successful" alert
    @State private var showResetSuccess = false
    
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
                    .blur(radius: showPrompt ? 3 : 0)  // Blur if prompt is active
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
            // (Optional) Cleanup
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
        }
    }
}

// MARK: - Fetch Status
extension ThoughtNavigationView {
    private func fetchThoughtStatus() {
        isFetchingStatus = true
        socketViewModel.sendMessage(action: "thought_status", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "thought_chapters" }
            .first()
            .sink { message in
                DispatchQueue.main.async {
                    self.isFetchingStatus = false
                    self.handleThoughtStatusResponse(message)
                    // Clear to avoid repeated triggers
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    private func handleThoughtStatusResponse(_ message: [String: Any]) {
        guard
            let status = message["status"] as? String, status == "success",
            let data   = message["data"] as? [String: Any]
        else {
            // Could show an error message
            return
        }
        
        let statusString  = data["status"] as? String ?? "not_started"
        let thoughtId     = data["thought_id"] as? Int ?? thought.id
        let thoughtName   = data["thought_name"] as? String ?? thought.name
        let progressDict  = data["progress"] as? [String: Any] ?? [:]
        let chaptersArray = data["chapters"] as? [[String: Any]] ?? []
        
        let progressData = ProgressData(
            total: progressDict["total"] as? Int ?? 0,
            completed: progressDict["completed"] as? Int ?? 0,
            remaining: progressDict["remaining"] as? Int ?? 0
        )
        
        let chapters = chaptersArray.map { ch -> ChapterDataModel in
            ChapterDataModel(
                chapter_number: ch["chapter_number"] as? Int ?? 0,
                title: ch["title"] as? String ?? "",
                content: ch["content"] as? String ?? "",
                status: ch["status"] as? String ?? ""
            )
        }
        
        let newStatus = ThoughtStatus(
            thought_id: thoughtId,
            thought_name: thoughtName,
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
                Text("It seems you are in the middle of the stream / reading for \(thoughtStatus?.thought_name ?? thought.name).")
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
                Text("It seems you have finished \(thoughtStatus?.thought_name ?? thought.name).")
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
        socketViewModel.sendMessage(action: "reset_reading", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "reset_response" }
            .first()
            .sink { message in
                DispatchQueue.main.async {
                    self.handleResetResponse(message)
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    private func handleResetResponse(_ message: [String: Any]) {
        guard let status = message["status"] as? String, status == "success" else {
            // handle error
            return
        }
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
