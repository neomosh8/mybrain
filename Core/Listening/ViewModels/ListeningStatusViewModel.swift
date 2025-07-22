import SwiftUI
import Combine

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
