import Foundation

enum WebSocketMessage {
    case streamingLinks(thoughtId: String)
    case nextChapter(thoughtId: String, generateAudio: Bool)
    case feedback(thoughtId: String, chapterNumber: Int, word: String, value: Double)
    case response(action: String, data: [String: Any])
    case listThoughts
    case thoughtChapters(thoughtId: String)
    case error(message: String)
    
    func toDictionary() -> [String: Any] {
        switch self {
        case .listThoughts:
            return [
                "action": "list_thoughts"
            ]
            
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
            
        case .thoughtChapters(let thoughtId):
            return [
                "action": "thought_chapters",
                "data": ["thought_id": thoughtId]
            ]
            
        case .response(let action, let data):
            return [
                "action": action,
                "data": data
            ]
            
        case .error(let message):
            return [
                "error": message
            ]
        }
    }
}
