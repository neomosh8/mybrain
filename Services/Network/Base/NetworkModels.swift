import Foundation

// MARK: - HTTP Models

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    let body: Data?
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
    
    init(path: String,
         method: HTTPMethod,
         headers: [String: String]? = nil,
         queryItems: [URLQueryItem]? = nil,
         body: Encodable? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        
        if let body = body {
            let encoder = JSONEncoder()
            self.body = try? encoder.encode(body)
        } else {
            self.body = nil
        }
    }
}

enum NetworkError: Error, Equatable {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(statusCode: Int, message: String)
    case unauthorized
    case noConnection
    case timeout
    case unknown
    
    // MARK: - Equatable Implementation
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
            (.invalidResponse, .invalidResponse),
            (.unauthorized, .unauthorized),
            (.noConnection, .noConnection),
            (.timeout, .timeout),
            (.unknown, .unknown):
            return true
        case (.requestFailed(let lhsError), .requestFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.decodingFailed(let lhsError), .decodingFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (
            .serverError(let lhsCode, let lhsMessage),
            .serverError(let rhsCode, let rhsMessage)
        ):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
        
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
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .unauthorized:
            return "Authentication required"
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

struct EmptyResponse: Codable {}

// MARK: - WebSocket Models

struct StreamingLinks: Codable {
    let masterPlaylist: String
    let subtitlesPlaylist: String?
    
    enum CodingKeys: String, CodingKey {
        case masterPlaylist = "master_playlist"
        case subtitlesPlaylist = "subtitles_playlist"
    }
}

struct ChapterInfo: Codable {
    let chapterNumber: Int
    let title: String
    let content: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case title
        case content
        case status
    }
}

struct UploadResponse: Codable {
    let fileUrl: String
    let status: String
}
