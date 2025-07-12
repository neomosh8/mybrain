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
        let boundary = UUID().uuidString
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(contentType)\r\n".data(using: .utf8)!)
        
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
    
    func getThoughtStatus(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtStatus>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtDetail(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtStatus.self)
    }
    
    func resetThoughtProgress(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.resetThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: ThoughtOperationResponse.self)
    }
    
    func retryFailedThought(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.retryThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: ThoughtOperationResponse.self)
    }
    
    func passChapters(thoughtId: String, upToChapter: Int) -> AnyPublisher<NetworkResult<PassChaptersResponse>, Never> {
        let body = ["up_to_chapter": upToChapter]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.passChapters(thoughtId),
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: PassChaptersResponse.self)
    }
    
    func summarizeChapters(thoughtId: String) -> AnyPublisher<NetworkResult<SummarizeResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.summarizeThought(thoughtId),
            method: .POST
        )
        return request(endpoint, responseType: SummarizeResponse.self)
    }
    
    func archiveThought(thoughtId: String) -> AnyPublisher<NetworkResult<ArchiveThoughtResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.deleteThought(thoughtId),
            method: .DELETE
        )
        return request(endpoint, responseType: ArchiveThoughtResponse.self)
    }
    
    func getThoughtFeedbacks(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtFeedbacksResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtFeedbacks(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtFeedbacksResponse.self)
    }
    
    func getThoughtBookmarks(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtBookmarksResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtBookmarks(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: ThoughtBookmarksResponse.self)
    }
    
    func getRetentionIssues(thoughtId: String) -> AnyPublisher<NetworkResult<RetentionIssuesResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.thoughtRetentions(thoughtId),
            method: .GET
        )
        return request(endpoint, responseType: RetentionIssuesResponse.self)
    }
}
