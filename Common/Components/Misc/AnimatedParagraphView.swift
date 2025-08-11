import SwiftUI

struct AnimatedParagraphView: View {
    @Binding var paragraphs: [[WordData]]
    @Binding var currentWordIndex: Int
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6
    var bottomPadding: CGFloat = 70

    var body: some View {
        ScrollView {
            AnimatedWordsView(
                paragraphs: paragraphs,
                currentWordIndex: currentWordIndex,
                showOverlay: currentWordIndex >= 0,
                spacing: spacing,
                lineSpacing: lineSpacing,
                bottomPadding: bottomPadding
            )
            .padding()
        }
    }
}
