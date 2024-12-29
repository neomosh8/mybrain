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
                Text(buildSubtitleAttributedString(words: segment.words, highlightIndex: highlightIndex))
                    .padding()
                    // Comment this in or out depending on whether you want
                    // the highlight color to animate in/out:
                    // .animation(.easeInOut, value: highlightIndex)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Loading subtitles...")
        }
    }
    
    
    func buildSubtitleAttributedString(words: [WordTimestamp], highlightIndex: Int?) -> AttributedString {
        var result = AttributedString()
        
        for (idx, word) in words.enumerated() {
            var attributedString = AttributedString(word.text + " ")
            
            // Use a consistent font for all words:
            var attributes = AttributeContainer()
            attributes.font = .system(size: 16, weight: .regular)
            
            // Only change background (and maybe foreground) color for the highlighted word
            if idx == highlightIndex {
                attributes.backgroundColor = .yellow
                attributes.foregroundColor = .black
            } else {
                attributes.foregroundColor = .primary
            }
            
            attributedString.mergeAttributes(attributes)
            result.append(attributedString)
        }
        return result
    }
}
