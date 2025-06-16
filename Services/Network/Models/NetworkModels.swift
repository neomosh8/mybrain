import Foundation

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    let body: Data?
    
    init(path: String,
         method: HTTPMethod,
         headers: [String: String]? = nil,
         queryItems: [URLQueryItem]? = nil,
         body: Data? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum NetworkResult<T> {
    case success(T)
    case failure(NetworkError)
}

enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case unauthorized
    case clientError(Int, String)
    case serverError(Int, String)
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required"
        case .clientError(let code, let message):
            return "Client error (\(code)): \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

enum WebSocketConnectionState {
    case connecting
    case connected
    case disconnected
    case failed(Error)
}
