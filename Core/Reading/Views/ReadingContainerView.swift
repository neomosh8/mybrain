
import SwiftUI
import Combine

/// Main entry point for reading mode - handles initial status check and navigation
struct ReadingContainerView: View {
    let thought: Thought
    
    var body: some View {
        ReadingStatusWrapper(thought: thought) {
            ReadingContentView(thought: thought)
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
    }
}
