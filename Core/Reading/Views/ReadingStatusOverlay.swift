import SwiftUICore
import SwiftUI

struct ReadingStatusOverlay: View {
    let thought: Thought
    let status: String
    let onResume: () -> Void
    let onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(overlayMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            if status == "in_progress" {
                HStack(spacing: 16) {
                    Button("Restart from Beginning") {
                        onRestart()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Resume") {
                        onResume()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Restart from Beginning") {
                    onRestart()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 32)
    }
    
    private var overlayMessage: String {
        switch status {
        case "in_progress":
            return "You're in the middle of reading \"\(thought.name)\". Would you like to continue where you left off?"
        case "finished":
            return "You've completed reading \"\(thought.name)\". Would you like to read it again?"
        default:
            return "Ready to start reading \"\(thought.name)\""
        }
    }
}
