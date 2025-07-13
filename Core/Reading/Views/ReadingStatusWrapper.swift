import SwiftUICore
import SwiftUI
import Combine

struct ReadingStatusWrapper<Content: View>: View {
    let thought: Thought
    @ViewBuilder let content: () -> Content
    
    private let networkService = NetworkServiceManager.shared
    
    @State private var thoughtStatus: ReadingThoughtStatus?
    @State private var isCheckingStatus = true
    @State private var showStatusOverlay = false
    @State private var showResetSuccess = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            if isCheckingStatus {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.gray)
                    Text("Checking reading status...")
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("EInkBackground"))
            } else {
                content()
                    .blur(radius: showStatusOverlay ? 3 : 0)
                
                if showStatusOverlay {
                    ReadingStatusOverlay(
                        thought: thought,
                        status: thoughtStatus?.status ?? "not_started",
                        onResume: {
                            showStatusOverlay = false
                        },
                        onRestart: {
                            resetReadingProgress()
                        }
                    )
                }
            }
        }
        .alert("Success", isPresented: $showResetSuccess) {
            Button("OK") { }
        } message: {
            Text("Reading progress reset successfully")
        }
        .onAppear {
            checkThoughtStatus()
        }
    }
    
    private func checkThoughtStatus() {
        print("🔍 Starting status check for thought: \(thought.id)")
        isCheckingStatus = true
        
        networkService.thoughts.getThoughtStatus(thoughtId: thought.id)
            .receive(on: DispatchQueue.main)
            .sink { result in
                print("🔍 Status check completed with result: \(result)")

                self.isCheckingStatus = false
                
                switch result {
                case .success(let status):
                    self.thoughtStatus = ReadingThoughtStatus(
                        thoughtId: status.thoughtId,
                        status: status.status,
                        progress: status.progress
                    )
                    self.determineNavigationAction()
                    
                case .failure(let error):
                    print("Status check failed: \(error)")
                    // Set a default status instead of leaving thoughtStatus nil
                    self.thoughtStatus = ReadingThoughtStatus(
                        thoughtId: thought.id,
                        status: "not_started",
                        progress: ThoughtProgress(total: 0, completed: 0, remaining: 0)
                    )
                    self.showStatusOverlay = false 
                }
            }
            .store(in: &cancellables)
    }
    
    private func determineNavigationAction() {
        guard let status = thoughtStatus else { return }
        
        switch status.status {
        case "not_started":
            // Proceed directly to reading
            showStatusOverlay = false
        case "in_progress":
            // Show resume/restart overlay
            showStatusOverlay = true
        case "finished":
            // Show restart-only overlay
            showStatusOverlay = true
        default:
            showStatusOverlay = false
        }
    }
    
    private func resetReadingProgress() {
        networkService.thoughts.resetThoughtProgress(thoughtId: thought.id)
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .success:
                    self.showStatusOverlay = false
                    self.showResetSuccess = true
                    // Update local status
                    self.thoughtStatus?.status = "not_started"
                    
                case .failure(let error):
                    print("Reset failed: \(error)")
                    // Could show error alert here
                }
            }
            .store(in: &cancellables)
    }
}
