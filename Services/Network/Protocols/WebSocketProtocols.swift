import Foundation
import Combine

protocol WebSocketAPI {
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> { get }
    var messages: AnyPublisher<WebSocketMessage, Never> { get }
    var isConnected: Bool { get }
    
    func openSocket()
    func closeSocket()
    func requestStreamingLinks(thoughtId: String)
    func requestNextChapter(thoughtId: String, generateAudio: Bool)
    func sendFeedback(thoughtId: String, chapterNumber: Int, word: String, value: Double)
    func activateReceiveMessage(callback: @escaping (WebSocketMessage) -> Void)
    func requestThoughtStatus(thoughtId: String)
}
