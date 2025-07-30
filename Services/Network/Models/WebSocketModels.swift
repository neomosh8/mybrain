import Foundation

// MARK: - Outgoing Actions (Client → Server)

enum WebSocketAction {
    case streamingLinks(thoughtId: String)
    case nextChapter(thoughtId: String, generateAudio: Bool)
    case feedback(thoughtId: String, chapterNumber: Int, word: String, value: Double)
    case thoughtStatus(thoughtId: String)

    func toDictionary() -> [String: Any] {
        switch self {
        case .streamingLinks(let thoughtId):
            return [
                "action": "streaming_links",
                "data": ["thought_id": thoughtId]
            ]
            
        case .nextChapter(let thoughtId, let generateAudio):
            return [
                "action": "next_chapter",
                "data": [
                    "thought_id": thoughtId,
                    "generate_audio": generateAudio
                ]
            ]
            
        case .feedback(let thoughtId, let chapterNumber, let word, let value):
            return [
                "action": "feedback",
                "data": [
                    "thought_id": thoughtId,
                    "chapter_number": chapterNumber,
                    "word": word,
                    "value": value
                ]
            ]
            
        case .thoughtStatus(let thoughtId):
            return [
                "action": "thought_status",
                "data": ["thought_id": thoughtId]
            ]
        }
    }
}

// MARK: - Incoming Messages (Server → Client)

enum WebSocketMessage {
    case connectionResponse(status: WebSocketStatus, message: String, data: [String: Any])
    case chapterAudio(status: WebSocketStatus, message: String, data: [String: Any]?)
    case chapterText(status: WebSocketStatus, message: String, data: [String: Any]?)
    case chapterComplete(status: WebSocketStatus, message: String, data: [String: Any]?)
    case streamingLinksResponse(status: WebSocketStatus, message: String, data: [String: Any]?)
    case feedbackResponse(status: WebSocketStatus, message: String, data: [String: Any]?)
    case actionResponse(status: WebSocketStatus, message: String, data: [String: Any]?)
    case thoughtUpdate(status: WebSocketStatus, message: String, data: [String: Any])
    case thoughtStatus(status: WebSocketStatus, message: String, data: [String: Any]?)
    case unknown(type: String, status: WebSocketStatus, message: String, data: [String: Any]?)
    
    init(type: String, status: String, message: String, data: [String: Any]?) {
        let wsStatus = WebSocketStatus(rawValue: status) ?? .error
        let messageData = data ?? [:]
        
        switch type {
        case "connection_response":
            self = .connectionResponse(status: wsStatus, message: message, data: messageData)
        case "chapter_audio":
            self = .chapterAudio(status: wsStatus, message: message, data: data)
        case "chapter_text":
            self = .chapterText(status: wsStatus, message: message, data: data)
        case "chapter_complete":
            self = .chapterComplete(status: wsStatus, message: message, data: data)
        case "streaming_links":
            self = .streamingLinksResponse(status: wsStatus, message: message, data: data)
        case "feedback_response":
            self = .feedbackResponse(status: wsStatus, message: message, data: data)
        case "action_response":
            self = .actionResponse(status: wsStatus, message: message, data: data)
        case "thought_update":
            self = .thoughtUpdate(status: wsStatus, message: message, data: messageData)
        case "thought_status":
            self = .thoughtStatus(status: wsStatus, message: message, data: data)
        default:
            self = .unknown(type: type, status: wsStatus, message: message, data: data)
        }
    }
}

// MARK: - WebSocket Status

enum WebSocketStatus: String, CaseIterable {
    case success = "success"
    case error = "error"
    case info = "info"
    
    var isSuccess: Bool {
        return self == .success
    }
    
    var isError: Bool {
        return self == .error
    }
    
    var isInfo: Bool {
        return self == .info
    }
}

// MARK: - Helper Extensions

extension WebSocketMessage {
    var status: WebSocketStatus {
        switch self {
        case .connectionResponse(let status, _, _),
             .chapterAudio(let status, _, _),
             .chapterText(let status, _, _),
             .chapterComplete(let status, _, _),
             .streamingLinksResponse(let status, _, _),
             .feedbackResponse(let status, _, _),
             .actionResponse(let status, _, _),
             .thoughtUpdate(let status, _, _),
             .thoughtStatus(let status, _, _),
             .unknown(_, let status, _, _):
            return status
        }
    }
    
    var message: String {
        switch self {
        case .connectionResponse(_, let message, _),
             .chapterAudio(_, let message, _),
             .chapterText(_, let message, _),
             .chapterComplete(_, let message, _),
             .streamingLinksResponse(_, let message, _),
             .feedbackResponse(_, let message, _),
             .actionResponse(_, let message, _),
             .thoughtUpdate(_, let message, _),
             .thoughtStatus(_, let message, _),
             .unknown(_, _, let message, _):
            return message
        }
    }
    
    var data: [String: Any]? {
        switch self {
        case .connectionResponse(_, _, let data):
            return data
        case .chapterAudio(_, _, let data),
             .chapterText(_, _, let data),
             .chapterComplete(_, _, let data),
             .streamingLinksResponse(_, _, let data),
             .feedbackResponse(_, _, let data),
             .actionResponse(_, _, let data),
             .thoughtStatus(_, _, let data),
             .unknown(_, _, _, let data):
            return data
        case .thoughtUpdate(_, _, let data):
            return data
        }
    }
    
    var type: String {
        switch self {
        case .connectionResponse:
            return "connection_response"
        case .chapterAudio:
            return "chapter_audio"
        case .chapterText:
            return "chapter_text"
        case .chapterComplete:
            return "chapter_complete"
        case .streamingLinksResponse:
            return "streaming_links"
        case .feedbackResponse:
            return "feedback_response"
        case .actionResponse:
            return "action_response"
        case .thoughtUpdate:
            return "thought_update"
        case .thoughtStatus:
            return "thought_status"
        case .unknown(let type, _, _, _):
            return type
        }
    }
}

// MARK: - Specific Response Data Models

struct ConnectionResponseData {
    let user: String?
    
    init?(from data: [String: Any]) {
        self.user = data["user"] as? String
    }
}

struct ChapterAudioResponseData {
    let chapterNumber: Int?
    let title: String?
    let audioDuration: Double?
    let generationTime: Double?
    let words: [[String: Any]]?
    
    init?(from data: [String: Any]?) {
        guard let data = data else { return nil }
        
        self.chapterNumber = data["chapter_number"] as? Int
        self.title = data["title"] as? String
        self.audioDuration = data["audio_duration"] as? Double
        self.generationTime = data["generation_time"] as? Double
        self.words = data["words"] as? [[String: Any]]
    }
}

struct ChapterTextResponseData {
    let chapterNumber: Int?
    let title: String?
    let content: String?
    let contentWithImage: String?
    let generationTime: Double?
    
    init?(from data: [String: Any]?) {
        guard let data = data else { return nil }
        
        self.chapterNumber = data["chapter_number"] as? Int
        self.title = data["title"] as? String
        self.content = data["content"] as? String
        self.contentWithImage = data["content_with_image"] as? String
        self.generationTime = data["generation_time"] as? Double
    }
}

struct ChapterCompleteResponseData {
    let thoughtId: String?
    let complete: Bool?
    
    init?(from data: [String: Any]?) {
        guard let data = data else { return nil }
        
        self.thoughtId = data["thought_id"] as? String
        self.complete = data["complete"] as? Bool
    }
}

struct StreamingLinksResponseData {
    let masterPlaylist: String?
    let audioPlaylist: String?
    let subtitlesPlaylist: String?
    let thoughtId: String?
    let complete: Bool?
    
    init?(from data: [String: Any]?) {
        guard let data = data else { return nil }
        
        self.masterPlaylist = data["master_playlist"] as? String
        self.audioPlaylist = data["audio_playlist"] as? String
        self.subtitlesPlaylist = data["subtitles_playlist"] as? String
        self.thoughtId = data["thought_id"] as? String
        self.complete = data["complete"] as? Bool
    }
}

struct FeedbackResponseData {
    let thoughtId: String?
    let chapterNumber: Int?
    let word: String?
    
    init?(from data: [String: Any]?) {
        guard let data = data else { return nil }
        
        self.thoughtId = data["thought_id"] as? String
        self.chapterNumber = data["chapter_number"] as? Int
        self.word = data["word"] as? String
    }
}

struct ThoughtUpdateData {
    let thought: ThoughtData
    
    init?(from data: [String: Any]) {
        guard let thoughtData = data["thought"] as? [String: Any],
              let validThought = ThoughtData(from: thoughtData) else {
            return nil
        }
        
        self.thought = validThought
    }
}

struct ThoughtData {
    let id: String
    let name: String
    let cover: String?
    let model3d: String?
    let createdAt: String
    let updatedAt: String
    let status: String
    let progress: ThoughtProgress?
    
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let createdAt = data["created_at"] as? String,
              let updatedAt = data["updated_at"] as? String,
              let status = data["status"] as? String else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.cover = data["cover"] as? String
        self.model3d = data["model_3d"] as? String
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.progress = Self.parseProgress(from: data)
    }
    
    private static func parseProgress(from data: [String: Any]) -> ThoughtProgress? {
        guard let progressData = data["progress"] as? [String: Any],
              let total = progressData["total"] as? Int,
              let completed = progressData["completed"] as? Int,
              let remaining = progressData["remaining"] as? Int else {
            return nil
        }
        
        return ThoughtProgress(total: total, completed: completed, remaining: remaining)
    }
}
