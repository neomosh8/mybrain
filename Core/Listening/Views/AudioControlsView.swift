import SwiftUI
import AVFoundation

struct AudioControlsView: View {
    @ObservedObject var viewModel: AudioStreamingViewModel
    
    var body: some View {
        VStack(spacing: 20) {            
            // Main controls
            HStack(spacing: 40) {                
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
            }
            
            // Time labels
            if let player = viewModel.player {
                TimeLabelsView(player: player)
            }
        }
    }
}

struct TimeLabelsView: View {
    let player: AVPlayer
    @State private var currentTime: Double = 0
    
    var body: some View {
        HStack {
            Text(formatTime(currentTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateTimes()
        }
        .onAppear {
            updateTimes()
        }
    }
    
    private func updateTimes() {
        let current = player.currentTime().seconds
        
        if current.isFinite {
            currentTime = current
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
