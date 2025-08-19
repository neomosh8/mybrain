import Foundation

// MARK: - Listening State

enum ListeningState {
    case idle
    case fetchingLinks
    case ready
    case playing
    case paused
    case buffering
    case error(Error)
    case completed
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

// MARK: - Chapter Management

struct ChapterInfo {
    let number: Int
    let title: String?
    let duration: TimeInterval?
    let startTime: TimeInterval
    let isComplete: Bool
    let generationTime: Double?

    init(
        number: Int,
        title: String? = nil,
        duration: TimeInterval? = nil,
        startTime: TimeInterval = 0,
        isComplete: Bool = false,
        generationTime: Double? = nil
    ) {
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
                print("🎵 Updating current chapter from \(currentChapter?.number ?? 0) to \(activeChapter.number)")
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

enum ListeningError: LocalizedError {
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

struct WordTimestamp: Equatable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String

    static func == (lhs: WordTimestamp, rhs: WordTimestamp) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end && lhs.text == rhs.text
    }
}
