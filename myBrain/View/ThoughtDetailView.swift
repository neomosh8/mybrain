import SwiftUI

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let chapter = socketViewModel.chapterData {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Chapter \(chapter.chapterNumber): \(chapter.title)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(chapter.content)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
            } else {
                ProgressView("Loading Chapter...")
                    .tint(.white)
            }
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            requestNextChapter()
        }
    }

    private func requestNextChapter() {
        let messageData: [String: Any] = [
            "thought_id": thought.id,
            "generate_audio": false
        ]
        socketViewModel.sendMessage(action: "next_chapter", data: messageData)
    }
}
