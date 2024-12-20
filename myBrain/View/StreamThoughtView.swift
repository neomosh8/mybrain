import SwiftUI

struct StreamThoughtView: View {
    let thought: Thought
    let socketViewModel: WebSocketViewModel

    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            Text("Stream View for \(thought.name)")
                .foregroundColor(.black)
        }
    }
}
