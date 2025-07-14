import Foundation
import Swift
import SwiftUI

// MARK: - Models

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


// MARK: - NEW CODE


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
