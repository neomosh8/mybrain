import Foundation
import Swift
import SwiftUI

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
