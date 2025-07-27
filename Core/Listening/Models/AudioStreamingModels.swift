import Foundation

// MARK: - Audio Streaming State

enum AudioStreamingState {
    case idle
    case fetchingLinks
    case ready
    case playing
    case paused
    case buffering
    case error(Error)
    case completed
}

// MARK: - Streaming Response Models

struct StreamingLinksResponse {
    let masterPlaylist: String
    let audioPlaylist: String?
    let subtitlesPlaylist: String?
    
    init?(from data: [String: Any]) {
        guard let masterPlaylist = data["master_playlist"] as? String else {
            return nil
        }
        
        self.masterPlaylist = masterPlaylist
        self.audioPlaylist = data["audio_playlist"] as? String
        self.subtitlesPlaylist = data["subtitles_playlist"] as? String
    }
}

struct ChapterResponse {
    let chapterNumber: Int
    let title: String?
    let audioDuration: Double?
    let generationTime: Double?
    let isComplete: Bool
    
    init?(from data: [String: Any]) {
        guard let chapterNumber = data["chapter_number"] as? Int else {
            return nil
        }
        
        self.chapterNumber = chapterNumber
        self.title = data["title"] as? String
        self.audioDuration = data["audio_duration"] as? Double
        self.generationTime = data["generation_time"] as? Double
        self.isComplete = data["complete"] as? Bool ?? false
    }
}

// MARK: - Audio Progress Tracking

struct AudioProgress {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let chapterNumber: Int
    let totalChapters: Int?
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var remainingTime: TimeInterval {
        return max(0, duration - currentTime)
    }
}

// MARK: - Chapter Management

struct ChapterInfo {
    let number: Int
    let title: String?
    let duration: TimeInterval?
    let startTime: TimeInterval
    let isComplete: Bool
    let generationTime: Double?
    
    init(number: Int, title: String? = nil, duration: TimeInterval? = nil, startTime: TimeInterval = 0, isComplete: Bool = false, generationTime: Double? = nil) {
        self.number = number
        self.title = title
        self.duration = duration
        self.startTime = startTime
        self.isComplete = isComplete
        self.generationTime = generationTime
    }
}

class ChapterManager: ObservableObject {
    @Published var chapters: [ChapterInfo] = []
    @Published var currentChapter: ChapterInfo?
    @Published var totalDuration: TimeInterval = 0
    
    func addChapter(_ chapter: ChapterInfo) {
        chapters.removeAll { $0.number == chapter.number }
        
        chapters.append(chapter)
        chapters.sort { $0.number < $1.number }
        
        updateTotalDuration()
    }
    
    func updateCurrentChapter(for currentTime: TimeInterval) {
        let activeChapter = chapters.first { chapter in
            let relativeStart = chapter.startTime
            let relativeEnd = relativeStart + (chapter.duration ?? 0)
            return currentTime >= relativeStart && currentTime < relativeEnd
        }
        
        if let activeChapter = activeChapter {
            if currentChapter?.number != activeChapter.number {
                print("🎵 ChapterManager: Updating current chapter from \(currentChapter?.number ?? 0) to \(activeChapter.number)")
                currentChapter = activeChapter
            }
        } else if currentChapter == nil && !chapters.isEmpty {
            currentChapter = chapters.first
        }
    }
    
    private func updateTotalDuration() {
        totalDuration = chapters.reduce(0) { total, chapter in
            total + (chapter.duration ?? 0)
        }
    }
    
    func getChapter(number: Int) -> ChapterInfo? {
        return chapters.first { $0.number == number }
    }
    
    func getNextChapter(after currentNumber: Int) -> ChapterInfo? {
        return chapters.first { $0.number > currentNumber }
    }
    
    func getPreviousChapter(before currentNumber: Int) -> ChapterInfo? {
        return chapters.last { $0.number < currentNumber }
    }
}

// MARK: - Audio Error Types

enum AudioStreamingError: LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case playerSetupFailed(Error)
    case streamingLinksUnavailable
    case chapterLoadFailed
    case audioSessionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid streaming URL: \(url)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .playerSetupFailed(let error):
            return "Player setup failed: \(error.localizedDescription)"
        case .streamingLinksUnavailable:
            return "Streaming links are not available"
        case .chapterLoadFailed:
            return "Failed to load chapter content"
        case .audioSessionFailed(let error):
            return "Audio session error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL, .streamingLinksUnavailable:
            return "Please try again or contact support if the problem persists."
        case .networkError:
            return "Check your internet connection and try again."
        case .playerSetupFailed, .audioSessionFailed:
            return "Restart the app and try again."
        case .chapterLoadFailed:
            return "Skip to the next chapter or try again."
        }
    }
}

// MARK: - Playback Configuration

struct AudioPlaybackConfig {
    let bufferDuration: TimeInterval
    let chapterRequestBuffer: TimeInterval
    let enableBackgroundPlayback: Bool
    let enableLockScreenControls: Bool
    
    static let `default` = AudioPlaybackConfig(
        bufferDuration: 30.0,
        chapterRequestBuffer: 60.0,
        enableBackgroundPlayback: true,
        enableLockScreenControls: true
    )
}

// MARK: - Subtitle Integration Models

struct SubtitleSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let chapterNumber: Int
    
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
}

struct SubtitleSegmentLink: Equatable {
    let urlString: String
    let minStart: Double
    let maxEnd: Double
    
    
    static func == (lhs: SubtitleSegmentLink, rhs: SubtitleSegmentLink) -> Bool {
        return lhs.urlString == rhs.urlString &&
        lhs.minStart == rhs.minStart &&
        lhs.maxEnd == rhs.maxEnd
    }
}

struct SubtitlePlaylist {
    let segments: [SubtitleSegment]
    let totalDuration: TimeInterval
    
    func getActiveSubtitle(at time: TimeInterval) -> SubtitleSegment? {
        return segments.first { $0.contains(time: time) }
    }
    
    func getSubtitles(in range: ClosedRange<TimeInterval>) -> [SubtitleSegment] {
        return segments.filter { subtitle in
            subtitle.startTime <= range.upperBound && subtitle.endTime >= range.lowerBound
        }
    }
}



struct WordTimestamp: Equatable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String
    
    
    static func == (lhs: WordTimestamp, rhs: WordTimestamp) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end && lhs.text == rhs.text
    }
}

struct SubtitleSegmentData {
    let paragraph: String
    let words: [WordTimestamp]
    let minStart: Double
    let maxEnd: Double
    
    var duration: Double {
        maxEnd - minStart
    }
}

struct WordGroup: Identifiable {
    let id = UUID()
    let words: [WordTimestamp]
    let startIndex: Int
}

extension Array where Element == WordTimestamp {
    func createWordGroups(wordsPerGroup: Int = 15) -> [WordGroup] {
        var groups: [WordGroup] = []
        
        for i in stride(from: 0, to: self.count, by: wordsPerGroup) {
            let endIndex = Swift.min(i + wordsPerGroup, self.count)
            let groupWords = Array(self[i..<endIndex])
            groups.append(WordGroup(words: groupWords, startIndex: i))
        }
        
        return groups
    }
}
