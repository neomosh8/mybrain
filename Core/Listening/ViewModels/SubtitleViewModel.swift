import SwiftUI
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var allWords: [WordTimestamp] = []
    @Published var currentWordIndex: Int = -1
    
    private var lastUpdateTime: TimeInterval = -1

    // MARK: - New method to load words directly from server data
    func loadWordsFromChapterAudio(words: [[String: Any]]) {
        let newWords = words.compactMap { wordData -> WordTimestamp? in
            guard let text = wordData["text"] as? String,
                  let start = wordData["start"] as? Double,
                  let end = wordData["end"] as? Double else {
                return nil
            }
            
            let adjustedEnd = max(end, start + 0.3)
            return WordTimestamp(start: start, end: adjustedEnd, text: text)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.appendNewWords(newWords)
        }
    }
    
    private func appendNewWords(_ newWords: [WordTimestamp]) {
        print("🎵 appendNewWords called with \(newWords.count) words")

        if !newWords.isEmpty {
            allWords.append(contentsOf: newWords)
            allWords.sort { $0.start < $1.start }
            
            print("🎵 Total words now: \(allWords.count)")
            print("🎵 First word: \(allWords.first?.text ?? "none"), Last word: \(allWords.last?.text ?? "none")")
            
            if newWords.first != nil {
                lastUpdateTime = -1
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("ResumePlaybackAfterGap"),
                        object: nil
                    )
                }
                
            }
        }
    }
    
    func updateCurrentTime(_ globalTime: Double) {
        guard abs(globalTime - lastUpdateTime) > 0.05 else { return }
        lastUpdateTime = globalTime
        
        let previousWordIndex = currentWordIndex
        
        let newIndex = allWords.firstIndex { word in
            if word.start == word.end {
                return abs(globalTime - word.start) < 0.05
            } else {
                return globalTime >= word.start && globalTime <= word.end
            }
        }
        
        currentWordIndex = newIndex ?? previousWordIndex
    }
   
    // MARK: - Reset functionality for new content
    func resetForNewThought() {
        allWords.removeAll()
        currentWordIndex = -1
        lastUpdateTime = -1
    }
}
