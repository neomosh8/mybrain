import SwiftUI
import AVFoundation

struct AudioControlsView: View {
    @ObservedObject var viewModel: AudioStreamingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            if let player = viewModel.player {
                ProgressBarView(player: player)
            }
            
            // Main controls
            HStack(spacing: 40) {
                // Skip backward button
                Button(action: {
                    skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                
                // Play/Pause button
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
                
                // Skip forward button
                Button(action: {
                    skipForward()
                }) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
            }
            
            // Time labels
            if let player = viewModel.player {
                TimeLabelsView(player: player)
            }
        }
    }
    
    private func skipBackward() {
        guard let player = viewModel.player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 15, preferredTimescale: 1))
        let boundedTime = CMTimeMaximum(newTime, CMTime.zero)
        player.seek(to: boundedTime)
    }
    
    private func skipForward() {
        guard let player = viewModel.player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: 30, preferredTimescale: 1))
        
        if let duration = player.currentItem?.duration,
           duration.isValid && !duration.isIndefinite {
            let boundedTime = CMTimeMinimum(newTime, duration)
            player.seek(to: boundedTime)
        } else {
            player.seek(to: newTime)
        }
    }
}

struct ProgressBarView: View {
    let player: AVPlayer
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: isDragging ? $dragValue : $currentTime,
                in: 0...max(duration, 1),
                onEditingChanged: { editing in
                    isDragging = editing
                    if !editing {
                        let targetTime = CMTime(seconds: dragValue, preferredTimescale: 1)
                        player.seek(to: targetTime)
                    }
                }
            )
            .accentColor(.blue)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if !isDragging {
                updateProgress()
            }
        }
        .onAppear {
            updateProgress()
        }
    }
    
    private func updateProgress() {
        let current = player.currentTime().seconds
        let total = player.currentItem?.duration.seconds ?? 0
        
        if current.isFinite {
            currentTime = current
        }
        
        if total.isFinite {
            duration = total
        }
        
        if isDragging {
            dragValue = currentTime
        }
    }
}

struct TimeLabelsView: View {
    let player: AVPlayer
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    
    var body: some View {
        HStack {
            Text(formatTime(currentTime))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(formatTime(duration))
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
        let total = player.currentItem?.duration.seconds ?? 0
        
        if current.isFinite {
            currentTime = current
        }
        
        if total.isFinite {
            duration = total
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
