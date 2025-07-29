import SwiftUI
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var allWords: [WordTimestamp] = []
    @Published var currentWordIndex: Int = -1
    
    private var loadedVTTFiles: Set<String> = []
    private var lastUpdateTime: TimeInterval = -1

    func loadChapterSubtitles(playlistURL: String, chapterOffset: Double) {
        print("🎵 Loading subtitles from: \(playlistURL)")
        
        fetchOnlyNewVTTFiles(playlistURL: playlistURL) { [weak self] newWords in
            DispatchQueue.main.async {
                self?.appendNewWords(newWords)
            }
        }
    }
    
    private func appendNewWords(_ newWords: [WordTimestamp]) {
        if !newWords.isEmpty {
            allWords.append(contentsOf: newWords)
            // Sort to maintain chronological order
            allWords.sort { $0.start < $1.start }
            
            print("🎵 Added \(newWords.count) new words")
            print("🎵 Total words loaded: \(allWords.count)")
            
            if let firstNewWord = newWords.first {
                print("🎵 New chapter starts at: \(firstNewWord.start)")
                // Trigger immediate update to pick up new words
                lastUpdateTime = -1 // Reset to force update
                
                // Resume playback in case it paused during the gap
                DispatchQueue.main.async {
                    // You'll need to pass the player reference or call through a delegate
                    // Option 1: If you have access to the player
                    // player?.play()
                    
                    // Option 2: Post a notification that AudioStreamingViewModel can listen to
                    NotificationCenter.default.post(
                        name: Notification.Name("ResumePlaybackAfterGap"),
                        object: nil
                    )
                }
                
            }
        } else {
            print("🎵 No new words to add")
        }
    }
    
    func updateCurrentTime(_ globalTime: Double) {
        guard abs(globalTime - lastUpdateTime) > 0.05 else { return }
        lastUpdateTime = globalTime

        if let firstWord = allWords.first, let lastWord = allWords.last {
            if globalTime < firstWord.start || globalTime > lastWord.end {
                print("🎵 Player time \(globalTime) is outside word range (\(firstWord.start)-\(lastWord.end))")
            }
        }
        
        let newIndex = allWords.firstIndex { word in
            if word.start == word.end {
                return abs(globalTime - word.start) < 0.05
            } else {
                return globalTime >= word.start && globalTime <= word.end
            }
        } ?? -1

        if newIndex != currentWordIndex {
            // If no word found but we had a valid word before, keep the last valid word
            if newIndex == -1 && currentWordIndex >= 0 {
                // Check if we're in a gap between chapters (next chapter loading)
                let lastWordTime = allWords.last?.end ?? 0
                if globalTime > lastWordTime && globalTime < (lastWordTime + 10) {
                    // We're in a loading gap, don't change the index
                    print("🎵 In chapter loading gap at time: \(globalTime)")
                    return
                }
            }
            
            print("🎵 Time: \(globalTime) -> Word index: \(newIndex) (was \(currentWordIndex))")
            if newIndex >= 0 && newIndex < allWords.count {
                print("🎵 Current word: '\(allWords[newIndex].text)' (\(allWords[newIndex].start)-\(allWords[newIndex].end))")
            }
            
            currentWordIndex = newIndex
        }
    }
    
    private func fetchOnlyNewVTTFiles(playlistURL: String, completion: @escaping ([WordTimestamp]) -> Void) {
        guard let url = URL(string: playlistURL) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("VTT playlist error: \(error)")
                completion([])
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }
            
            let allVTTFiles = self.extractVTTFiles(from: content, baseURL: playlistURL)
            let newVTTFiles = allVTTFiles.filter { !self.loadedVTTFiles.contains($0) }
            
            print("🎵 Found \(newVTTFiles.count) new VTT files out of \(allVTTFiles.count) total")
            
            if newVTTFiles.isEmpty {
                completion([])
                return
            }
            
            // Mark these files as loaded before starting to download
            for file in newVTTFiles {
                self.loadedVTTFiles.insert(file)
            }
            
            self.loadVTTFiles(newVTTFiles) { newWords in
                completion(newWords)
            }
            
        }.resume()
    }
    
    private func extractVTTFiles(from content: String, baseURL: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var vttFiles: [String] = []
        
        for line in lines {
            if line.hasSuffix(".vtt") {
                if line.hasPrefix("http") {
                    vttFiles.append(line)
                } else if let baseURL = URL(string: baseURL) {
                    let fullURL = baseURL.deletingLastPathComponent().appendingPathComponent(line).absoluteString
                    vttFiles.append(fullURL)
                }
            }
        }
        
        return vttFiles
    }
    
    private func loadVTTFiles(_ vttFiles: [String], completion: @escaping ([WordTimestamp]) -> Void) {
        let group = DispatchGroup()
        var newWords: [WordTimestamp] = []
        let lock = NSLock()
        
        for vttFile in vttFiles {
            group.enter()
            fetchVTTContent(vttFile) { words in
                lock.lock()
                newWords.append(contentsOf: words)
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Sort by start time
            newWords.sort { $0.start < $1.start }
            completion(newWords)
        }
    }
    
    private func fetchVTTContent(_ vttURL: String, completion: @escaping ([WordTimestamp]) -> Void) {
        guard let url = URL(string: vttURL) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("VTT fetch error: \(error)")
                completion([])
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }
            
            let words = self.parseVTT(content: content)
            print("🎵 Parsed \(words.count) words from VTT: \(url.lastPathComponent)")
            completion(words)
            
        }.resume()
    }
    
    private func parseVTT(content: String) -> [WordTimestamp] {
        var words: [WordTimestamp] = []
        let lines = content.components(separatedBy: .newlines)
        let timeRegex = try! NSRegularExpression(pattern: #"(\d+:\d+:\d+\.\d+) --> (\d+:\d+:\d+\.\d+)"#)
        
        var currentStartTime: TimeInterval = 0
        var currentEndTime: TimeInterval = 0
        
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and WEBVTT header
            if line.isEmpty || line.hasPrefix("WEBVTT") || line.hasPrefix("NOTE") {
                continue
            }
            
            // Check if this line contains timing information
            if let match = timeRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let startTimeString = String(line[Range(match.range(at: 1), in: line)!])
                let endTimeString = String(line[Range(match.range(at: 2), in: line)!])
                
                currentStartTime = parseTimeString(startTimeString)
                currentEndTime = parseTimeString(endTimeString)
                continue
            }
            
            // Check if this line is a cue text (not a number and has content)
            if !line.allSatisfy({ $0.isNumber }) && !line.isEmpty {
                // Parse individual words with their specific timings
                let wordsInLine = parseWordsFromCueLine(line, defaultStart: currentStartTime, defaultEnd: currentEndTime)
                words.append(contentsOf: wordsInLine)
            }
        }
        
        return words
    }
    
    private func parseWordsFromCueLine(_ line: String, defaultStart: TimeInterval, defaultEnd: TimeInterval) -> [WordTimestamp] {
        var words: [WordTimestamp] = []
        
        // Handle lines with <v> tags for word-level timing
        if line.contains("<") {
            let pattern = #"<(\d+:\d+:\d+\.\d+)><c>([^<]+)</c>"#
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            
            for match in matches {
                if let timeRange = Range(match.range(at: 1), in: line),
                   let textRange = Range(match.range(at: 2), in: line) {
                    let timeString = String(line[timeRange])
                    let text = String(line[textRange])
                    let startTime = parseTimeString(timeString)
                    
                    words.append(WordTimestamp(
                        start: startTime,
                        end: startTime + 0.5,
                        text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }
        } else {
            // Fallback for simple text without word-level timing
            let lineWords = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            let wordDuration = (defaultEnd - defaultStart) / Double(lineWords.count)
            
            for (index, word) in lineWords.enumerated() {
                let startTime = defaultStart + (Double(index) * wordDuration)
                let endTime = startTime + wordDuration
                
                words.append(WordTimestamp(
                    start: startTime,
                    end: endTime,
                    text: word.trimmingCharacters(in: .punctuationCharacters)
                ))
            }
        }
        
        return words
    }
    
    private func parseTimeString(_ timeString: String) -> TimeInterval {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    // MARK: - Reset functionality for new content
    func resetForNewThought() {
        allWords.removeAll()
        loadedVTTFiles.removeAll()
        currentWordIndex = -1
        lastUpdateTime = -1
        print("🎵 Subtitle state reset for new thought")
    }
}
