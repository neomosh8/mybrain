import Foundation
import Combine

protocol WebSocketAPI {
    var connectionState: AnyPublisher<WebSocketConnectionState, Never> { get }
    var messages: AnyPublisher<WebSocketMessage, Never> { get }
    var isConnected: Bool { get }
    
    func openSocket()
    func closeSocket()
    func sendStreamingLinks(thoughtId: Int)
    func sendNextChapter(thoughtId: Int, generateAudio: Bool)
    func sendFeedback(thoughtId: Int, chapterNumber: Int, word: String, value: Double)
    func activateReceiveMessage(callback: @escaping (WebSocketMessage) -> Void)
}
