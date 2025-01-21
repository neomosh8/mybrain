import SwiftUI
import AVKit
import Combine

/// A SwiftUI view that displays the currentSegment’s paragraph, highlighting the active word.
struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    let thoughtId: Int
    let chapterNumber: Int
    let socketViewModel: WebSocketViewModel

    /// Track the last highlighted index so we only send feedback once per word.
    @State private var lastHighlightedIndex: Int?

    var body: some View {
        if let segment = viewModel.currentSegment {
            // Determine which word to highlight
            let highlightIndex = segment.words.firstIndex {
                let gTime = viewModel.currentGlobalTime
                return gTime >= $0.start && gTime < $0.end
            }

            ScrollView {
                // Build the styled subtitle text
                Text(buildSubtitleAttributedString(words: segment.words, highlightIndex: highlightIndex))
                    .padding()
                    .fixedSize(horizontal: false, vertical: true)
                    // Whenever highlightIndex changes, call the feedback function
                    .onChange(of: highlightIndex) { newIndex in
                        // Ensure we only send feedback if it's a valid
                        // new index different from the previous one.
                        if let ni = newIndex, ni != lastHighlightedIndex {
                            sendFeedbackForWord(at: ni, in: segment.words)
                            lastHighlightedIndex = ni
                        }
                    }
            }
        } else {
            Text("Loading subtitles...")
        }
    }

    /// Builds an AttributedString with the highlighted word.
    func buildSubtitleAttributedString(words: [WordTimestamp], highlightIndex: Int?) -> AttributedString {
        var result = AttributedString()

        for (idx, word) in words.enumerated() {
            var attributedString = AttributedString(word.text + " ")

            // Use a consistent font for all words
            var attributes = AttributeContainer()
            attributes.font = .system(size: 16, weight: .regular)

            // Highlight if this is the active word
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

    /// Sends feedback for the newly highlighted word.
    private func sendFeedbackForWord(at index: Int, in words: [WordTimestamp]) {
        guard index >= 0 && index < words.count else { return }
        let plainWord = words[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        let randomValue = Double.random(in: 1...100)


        let feedbackData: [String: Any] = [
            "thought_id": thoughtId,
            "chapter_number": chapterNumber,
            "word": plainWord,
            "value": randomValue
        ]

        // Send feedback via your socket or network code
         socketViewModel.sendMessage(action: "feedback", data: feedbackData)
        print("Feedback sent:", feedbackData)
    }
}
