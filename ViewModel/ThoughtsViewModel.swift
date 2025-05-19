import SwiftUI

class ThoughtsViewModel: ObservableObject {
    @Published var thoughts: [Thought] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let baseUrl = "https://brain.sorenapp.ir"
    private var accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func fetchThoughts() {
        guard let url = URL(string: baseUrl + "/api/v1/thoughts/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        print("Fetching thoughts with token: \(accessToken)")
        print("Request URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                defer { self.isLoading = false }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("Request Error:", error.localizedDescription)
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received"
                    print("No data received from server.")
                    return
                }

                // Print the HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("Status Code:", httpResponse.statusCode)
                }

                // Print the raw response before decoding
                if let responseString = String(data: data, encoding: .utf8) {
                } else {
                    print("Failed to convert response data to string.")
                }

                // Attempt to decode the JSON
                do {
                    let decoded = try JSONDecoder().decode([Thought].self, from: data)
                    self.thoughts = decoded
                } catch {
                    self.errorMessage = "Failed to decode thoughts."
                    print("Decoding error:", error)
                }
            }
        }.resume()
    }
    func deleteThought(_ thought: Thought) {
        let token = self.accessToken
        guard let url = URL(string: "https://brain.sorenapp.ir/api/v1/thoughts/\(thought.id)/delete/") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Delete error:", error.localizedDescription)
                return
            }
            
            // If successful, remove it from local list
            DispatchQueue.main.async {
                self.thoughts.removeAll { $0.id == thought.id }
            }
        }
        task.resume()
    }

}
