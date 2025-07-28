import SwiftUI
import Combine

class SubtitleViewModel: ObservableObject {
    @Published var allWords: [WordTimestamp] = []
    @Published var currentWordIndex: Int = -1
    @Published var isLoading: Bool = false
    
    private var loadedWordCount: Int = 0
    private var lastUpdateTime: TimeInterval = -1

    func loadChapterSubtitles(playlistURL: String, chapterOffset: Double) {
        self.isLoading = true
        print("🎵 Loading subtitles from: \(playlistURL)")
        
        fetchAllVTTFiles(playlistURL: playlistURL) { [weak self] allWordsFromPlaylist in
            DispatchQueue.main.async {
                self?.appendOnlyNewWords(allWordsFromPlaylist)
                self?.isLoading = false
            }
        }
    }
    
    private func appendOnlyNewWords(_ allWordsFromPlaylist: [WordTimestamp]) {
        let sortedPlaylistWords = allWordsFromPlaylist.sorted { $0.start < $1.start }
        
        let newWords = sortedPlaylistWords.filter { playlistWord in
            !allWords.contains { existingWord in
                abs(existingWord.start - playlistWord.start) < 0.01 &&
                existingWord.text == playlistWord.text
            }
        }
        
        if !newWords.isEmpty {
            allWords.append(contentsOf: newWords)
            print("🎵 Added \(newWords.count) new words")
            print("🎵 Total words loaded: \(allWords.count)")
        } else {
            print("🎵 No new words to add")
        }
    }
    
    func updateCurrentTime(_ globalTime: Double) {
        guard abs(globalTime - lastUpdateTime) > 0.05 else { return }
        lastUpdateTime = globalTime

        let newIndex = allWords.firstIndex { word in
            if word.start == word.end {
                return abs(globalTime - word.start) < 0.05
            } else {
                return globalTime >= word.start && globalTime <= word.end
            }
        } ?? -1

        if newIndex != currentWordIndex {
            currentWordIndex = newIndex
        }
    }
    
    private func fetchAllVTTFiles(playlistURL: String, completion: @escaping ([WordTimestamp]) -> Void) {
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
            
            let vttFiles = self.extractVTTFiles(from: content, baseURL: playlistURL)
            self.loadAllVTTFiles(vttFiles) { allWords in
                completion(allWords)
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
    
    private func loadAllVTTFiles(_ vttFiles: [String], completion: @escaping ([WordTimestamp]) -> Void) {
        let group = DispatchGroup()
        var allWords: [WordTimestamp] = []
        let lock = NSLock()
        
        for vttFile in vttFiles {
            group.enter()
            fetchVTTContent(vttFile) { words in
                lock.lock()
                allWords.append(contentsOf: words)
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Sort by start time
            allWords.sort { $0.start < $1.start }
            completion(allWords)
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
            completion(words)
            
        }.resume()
    }
    
    private func parseVTT(content: String) -> [WordTimestamp] {
        var words: [WordTimestamp] = []
        let lines = content.components(separatedBy: .newlines)
        let timeRegex = try! NSRegularExpression(
            pattern: #"(\d+):(\d+):(\d+\.\d+)\s-->\s(\d+):(\d+):(\d+\.\d+)"#,
            options: []
        )
        
        for i in 0..<lines.count {
            let line = lines[i]
            if let match = timeRegex.firstMatch(
                in: line,
                options: [],
                range: NSRange(location: 0, length: line.utf16.count)) {
                
                guard let startTime = parseTime(from: line, match: match, isStart: true),
                      let endTime = parseTime(from: line, match: match, isStart: false)
                else { continue }
                
                // Get text from next lines
                var j = i + 1
                var cueTextLines: [String] = []
                while j < lines.count,
                      !lines[j].isEmpty,
                      timeRegex.firstMatch(in: lines[j], options: [], range: NSRange(location: 0, length: lines[j].utf16.count)) == nil {
                    cueTextLines.append(lines[j])
                    j += 1
                }
                
                let combinedText = cueTextLines.joined(separator: " ")
                let wordTexts = combinedText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                for wordText in wordTexts {
                    words.append(WordTimestamp(start: startTime, end: endTime, text: wordText))
                }
            }
        }
        
        return words
    }
    
    private func parseTime(from line: String, match: NSTextCheckingResult, isStart: Bool) -> Double? {
        let hourIndex = isStart ? 1 : 4
        let minuteIndex = isStart ? 2 : 5
        let secondIndex = isStart ? 3 : 6
        
        guard let hourRange = Range(match.range(at: hourIndex), in: line),
              let minuteRange = Range(match.range(at: minuteIndex), in: line),
              let secondRange = Range(match.range(at: secondIndex), in: line) else {
            return nil
        }
        
        let hours = Double(String(line[hourRange])) ?? 0
        let minutes = Double(String(line[minuteRange])) ?? 0
        let seconds = Double(String(line[secondRange])) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
}
