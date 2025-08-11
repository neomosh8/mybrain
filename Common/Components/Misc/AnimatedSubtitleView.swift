import SwiftUI

struct AnimatedSubtitleView: View {
    @Binding var paragraphs: [[WordData]]
    @Binding var currentWordIndex: Int
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6
    var bottomPadding: CGFloat = 70
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AnimatedWordsView(
                    paragraphs: paragraphs,
                    currentWordIndex: currentWordIndex,
                    showOverlay: currentWordIndex >= 0,
                    wordFont: .body,
                    spacing: spacing,
                    lineSpacing: lineSpacing,
                    bottomPadding: bottomPadding
                )
                .padding()
            }
            .onChange(of: currentWordIndex) { _, newIndex in
                if newIndex >= 15 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }
}
