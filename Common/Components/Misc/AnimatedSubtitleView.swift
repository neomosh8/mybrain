import SwiftUI
import NaturalLanguage

struct AnimatedSubtitleView: View {
    @ObservedObject var listeningViewModel: ListeningViewModel
    let thoughtId: String
    let chapterNumber: Int
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AnimatedWordsView(
                    paragraphs: listeningViewModel.paragraphs,
                    currentWordIndex: listeningViewModel.currentWordIndex,
                    showOverlay: listeningViewModel.currentWordIndex >= 0,
                    wordFont: .body,
                    spacing: 4,
                    lineSpacing: 6,
                    bottomPadding: 50
                )
                .padding()
            }
            .onChange(of: listeningViewModel.currentWordIndex) { _, newIndex in
                if newIndex >= 15 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onChange(of: listeningViewModel.allWords) { _, _ in
                listeningViewModel.buildParagraphs()
            }
            .onAppear {
                listeningViewModel.buildParagraphs()
            }
        }
    }
}
