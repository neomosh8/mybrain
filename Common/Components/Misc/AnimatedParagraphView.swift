import SwiftUI

struct AnimatedParagraphView: View {
    @Binding var paragraphs: [[WordData]]
    @Binding var currentWordIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AnimatedWordsView(
                    paragraphs: paragraphs,
                    currentWordIndex: currentWordIndex,
                    showOverlay: currentWordIndex >= 0
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
