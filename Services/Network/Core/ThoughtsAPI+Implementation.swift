import Foundation
import Combine

extension HTTPNetworkService: ThoughtsAPI {
    
    func createThoughtFromURL(url: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never> {
        let body = [
            "content_type": "url",
            "source": url
        ]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.createThought,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: ThoughtCreationResponse.self)
            .map { result in
                switch result {
                case .success(let response):
                    return .success(response.withProcessedURLs())
                case .failure(let error):
                    return .failure(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func createThoughtFromText(text: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never> {
        let body = [
            "content_type": "txt",
            "source": text
        ]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.createThought,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: ThoughtCreationResponse.self)
            .map { result in
                switch result {
                case .success(let response):
                    return .success(response.withProcessedURLs())
                case .failure(let error):
                    return .failure(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func createThoughtFromFile(
        fileData: Data,
        contentType: String,
        fileName: String
    ) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never> {
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add content_type field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(contentType)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.createThought,
            method: .POST,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: body
        )
        return request(endpoint, responseType: ThoughtCreationResponse.self)
            .map { result in
                switch result {
                case .success(let response):
                    return .success(response.withProcessedURLs())
                case .failure(let error):
                    return .failure(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getAllThoughts() -> AnyPublisher<NetworkResult<[Thought]>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughts,
            method: .GET
        )
        return request(endpoint, responseType: [Thought].self)
            .map { result in
                switch result {
                case .success(let thoughts):
                    return .success(thoughts.map { $0.withProcessedURLs() })
                case .failure(let error):
                    return .failure(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getThoughtStatus(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtStatus>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtDetail(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtStatus.self)
    }
    
    func resetThoughtProgress(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.resetThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: ThoughtOperationResponse.self)
    }
    
    func retryFailedThought(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.retryThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: ThoughtOperationResponse.self)
    }
    
    func passChapters(thoughtId: Int, upToChapter: Int) -> AnyPublisher<NetworkResult<PassChaptersResponse>, Never> {
        let body = ["up_to_chapter": upToChapter]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.passChapters(thoughtId),
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: PassChaptersResponse.self)
    }
    
    func summarizeChapters(thoughtId: Int) -> AnyPublisher<NetworkResult<SummarizeResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.summarizeThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: SummarizeResponse.self)
    }
    
    func archiveThought(thoughtId: Int) -> AnyPublisher<NetworkResult<ArchiveThoughtResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.deleteThought(thoughtId),
            method: .DELETE
        )
        return request(endpoint, responseType: ArchiveThoughtResponse.self)
    }
    
    func getThoughtFeedbacks(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtFeedbacksResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtFeedbacks(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtFeedbacksResponse.self)
    }
    
    func getThoughtBookmarks(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtBookmarksResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtBookmarks(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtBookmarksResponse.self)
    }
    
    func getRetentionIssues(thoughtId: Int) -> AnyPublisher<NetworkResult<RetentionIssuesResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtRetentions(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: RetentionIssuesResponse.self)
    }
}
