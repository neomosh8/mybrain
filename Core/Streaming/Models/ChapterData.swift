import Foundation
import Swift
import SwiftUI

// MARK: - Models

struct ThoughtStatus {
    let thought_id: Int
    let thought_name: String
    let status: String
    let progress: ProgressData
    let chapters: [ChapterDataModel]
    
    enum CodingKeys: String, CodingKey {
        case thoughtId = "thought_id"
        case thoughtName = "thought_name"
        case status
        case progress
        case chapters
    }
}

struct ProgressData {
    let total: Int
    let completed: Int
    let remaining: Int
}

struct ChapterDataModel {
    let chapter_number: Int
    let title: String
    let content: String
    let status: String
}


struct ChapterData: Equatable, Codable {
    let chapterNumber: Int
    let title: String
    let content: String
    let status: String
    let complete: Bool
    
    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case title
        case content
        case status
        case complete
    }
}

// MARK: - NEW CODE

/// A single link in the subtitles .m3u8, e.g. (vttURL, duration).
struct SubtitleSegmentLink {
    let urlString: String
    let duration: Double
    var minStart: Double
    var maxEnd: Double 
}

/// Each word in a single .vtt file.
struct WordTimestamp: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String
}

/// All data for one .vtt file (merged into a single paragraph, plus word-level timestamps).
struct SubtitleSegmentData {
    let paragraph: String
    let words: [WordTimestamp]
    let minStart: Double
    let maxEnd: Double
    
    var duration: Double {
        maxEnd - minStart
    }
}
