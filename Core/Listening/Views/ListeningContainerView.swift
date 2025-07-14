import SwiftUI
import Combine

struct ListeningContainerView: View {
    let thought: Thought
    
    @StateObject private var statusViewModel = ListeningStatusViewModel()
    @State private var showStatusOverlay = false
    @State private var showResetSuccess = false
    
    var body: some View {
        ZStack {
            AudioPlayerView(thought: thought)
                .blur(radius: showStatusOverlay ? 3 : 0)
            
            if showStatusOverlay {
                ListeningStatusOverlay(
                    thought: thought,
                    status: statusViewModel.thoughtStatus?.status ?? "not_started",
                    onResume: {
                        showStatusOverlay = false
                        // Resume listening - AudioPlayerView will handle this
                    },
                    onRestart: {
                        resetProgress()
                    }
                )
            }
        }
        .alert("Reset Successful", isPresented: $showResetSuccess) {
            Button("OK") { }
        } message: {
            Text("Listening progress has been reset successfully")
        }
        .onAppear {
            checkThoughtStatus()
        }
    }
    
    // MARK: - Status Management
    
    private func checkThoughtStatus() {
        statusViewModel.fetchThoughtStatus(thoughtId: thought.id) { status in
            DispatchQueue.main.async {
                determineNavigationAction(status: status)
            }
        }
    }
    
    private func determineNavigationAction(status: String) {
        switch status {
        case "not_started":
            // Proceed directly to listening
            showStatusOverlay = false
        case "in_progress", "finished":
            // Show overlay for user choice
            showStatusOverlay = true
        default:
            showStatusOverlay = false
        }
    }
    
    private func resetProgress() {
        statusViewModel.resetThoughtProgress(thoughtId: thought.id) { success in
            DispatchQueue.main.async {
                if success {
                    showStatusOverlay = false
                    showResetSuccess = true
                } else {
                    // Could show error alert here
                    print("Failed to reset progress")
                }
            }
        }
    }
}

// MARK: - Status ViewModel

@MainActor
class ListeningStatusViewModel: ObservableObject {
    @Published var thoughtStatus: ThoughtStatus?
    @Published var isLoading = false
    
    private let networkService = NetworkServiceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    func fetchThoughtStatus(thoughtId: String, completion: @escaping (String) -> Void) {
        isLoading = true
        
        networkService.thoughts.getThoughtStatus(thoughtId: thoughtId)
            .receive(on: DispatchQueue.main)
            .sink { result in
                self.isLoading = false
                switch result {
                case .success(let status):
                    self.thoughtStatus = status
                    completion(status.status)
                case .failure(let error):
                    print("Status check failed: \(error)")
                    // Default to not_started on error
                    completion("not_started")
                }
            }
            .store(in: &cancellables)
    }
    
    func resetThoughtProgress(thoughtId: String, completion: @escaping (Bool) -> Void) {
        networkService.thoughts.resetThoughtProgress(thoughtId: thoughtId)
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .success:
                    completion(true)
                case .failure(let error):
                    print("Reset failed: \(error)")
                    completion(false)
                }
            }
            .store(in: &cancellables)
    }
}
