import SwiftUI
import AVKit
import Combine
/// A SwiftUI view that displays the currentSegment’s paragraph, highlighting the active word.
struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    
    var body: some View {
        if let segment = viewModel.currentSegment {
            let highlightIndex = segment.words.firstIndex {
                let gTime = viewModel.currentGlobalTime
                return gTime >= $0.start && gTime < $0.end
            }
            
            ScrollView {
                Text(buildSubtitleString(words: segment.words, highlightIndex: highlightIndex))
                    .padding()
            }
        } else {
            Text("Loading subtitles...")
        }
    }
    
    func buildSubtitleString(words: [WordTimestamp], highlightIndex: Int?) -> String {
        var result = ""
        for (idx, word) in words.enumerated() {
            if idx == highlightIndex {
                // bracket or color highlight...
                result.append("[\(word.text)] ")
            } else {
                result.append("\(word.text) ")
            }
        }
        return result
    }
}
// MARK: - END NEW CODE
