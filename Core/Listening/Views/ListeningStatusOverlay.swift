import SwiftUI

struct ListeningStatusOverlay: View {
    let thought: Thought
    let status: String
    let onResume: () -> Void
    let onRestart: () -> Void
    
    @State private var isResetting = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Main overlay content
            VStack(spacing: 24) {
                // Thought info
                thoughtInfoSection
                
                // Status message
                statusMessageSection
                
                // Action buttons
                actionButtonsSection
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 10)
            )
            .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Subviews
    
    private var thoughtInfoSection: some View {
        VStack(spacing: 8) {
            // Thought cover or icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                )
            
            Text(thought.name)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
    
    private var statusMessageSection: some View {
        VStack(spacing: 8) {
            Text(statusTitle)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(statusMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if status == "in_progress" {
                // Show both Resume and Restart for in_progress
                Button(action: onResume) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Resume Listening")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: handleRestart) {
                    HStack {
                        if isResetting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Restart from Beginning")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isResetting)
                
            } else if status == "finished" {
                // Show only Restart for finished
                Button(action: handleRestart) {
                    HStack {
                        if isResetting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Listen Again")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isResetting)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusTitle: String {
        switch status {
        case "in_progress":
            return "Continue Listening?"
        case "finished":
            return "Already Completed"
        default:
            return "Ready to Listen"
        }
    }
    
    private var statusMessage: String {
        switch status {
        case "in_progress":
            return "You have partially listened to this thought. Would you like to resume where you left off or start over?"
        case "finished":
            return "You have already completed listening to this thought. Would you like to listen again from the beginning?"
        default:
            return "Ready to start listening to this thought."
        }
    }
    
    // MARK: - Actions
    
    private func handleRestart() {
        isResetting = true
        
        // Add a small delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRestart()
            isResetting = false
        }
    }
}
