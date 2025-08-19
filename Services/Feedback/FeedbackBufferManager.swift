import Foundation
import Combine

// MARK: - Feedback Buffer Manager
class FeedbackBufferManager: ObservableObject {
    // MARK: - Properties
    private var buffer: [FeedbackItem] = []
    private let bufferLimit: Int
    private let batchInterval: TimeInterval
    private var timer: Timer?
    
    // MARK: - Initialization
    init(
        bufferLimit: Int = 10,
        batchInterval: TimeInterval = 2.0,
    ) {
        self.bufferLimit = bufferLimit
        self.batchInterval = batchInterval
        startBatchTimer()
    }
    
    deinit {
        stopBatchTimer()
    }
    
    // MARK: - Public Methods
    
    func addFeedback(
        word: String,
        value: Double,
        thoughtId: String,
        chapterNumber: Int
    ) {
        let item = FeedbackItem(
            word: word,
            value: value,
            timestamp: Date(),
            thoughtId: thoughtId,
            chapterNumber: chapterNumber
        )
        
        buffer.append(item)
        
        if buffer.count >= bufferLimit {
            sendBatchFeedback()
        }
    }
    
    func flushBuffer() {
        guard !buffer.isEmpty else { return }
        sendBatchFeedback()
    }
    
    // MARK: - Private Methods
    
    private func startBatchTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.sendBatchFeedback()
        }
    }
    
    private func stopBatchTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func sendBatchFeedback() {
        guard !buffer.isEmpty else { return }
        
        // Group by thoughtId and chapterNumber
        let groupedFeedback = Dictionary(grouping: buffer) { item in
            "\(item.thoughtId)-\(item.chapterNumber)"
        }
        
        for (_, items) in groupedFeedback {
            guard let firstItem = items.first else { continue }
            
            let feedbacks = items.map { (word: $0.word, value: $0.value) }
            
            Task {
                await feedbackService.submitBatchFeedback(
                    thoughtId: firstItem.thoughtId,
                    chapterNumber: firstItem.chapterNumber,
                    feedbacks: feedbacks
                )
            }
        }
        
        buffer.removeAll()
    }
}
