import Foundation

enum WebSocketMessage {
    case streamingLinks(thoughtId: Int)
    case nextChapter(thoughtId: Int, generateAudio: Bool)
    case feedback(thoughtId: Int, chapterNumber: Int, word: String, value: Double)
    case response(action: String, data: [String: Any])
    
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
            
        case .response(let action, let data):
            return [
                "action": action,
                "data": data
            ]
        }
    }
}
