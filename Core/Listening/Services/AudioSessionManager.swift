import Foundation
import AVFoundation
import MediaPlayer
import UIKit

class AudioSessionManager: ObservableObject {
    static let shared = AudioSessionManager()
    
    @Published var isActive = false
    
    private init() {
        setupRemoteTransportControls()
    }
    
    // MARK: - Audio Session Management
    
    func activateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
            )
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isActive = true
            
            print("Audio session activated successfully")
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
    }
    
    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
            
            // Clear now playing info
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            
            print("Audio session deactivated successfully")
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Lock Screen Controls
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.handlePlayCommand()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.handlePauseCommand()
            return .success
        }
        
        // Skip forward command
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.handleSkipForwardCommand()
            return .success
        }
        
        // Skip backward command
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.handleSkipBackwardCommand()
            return .success
        }
        
        // Seek forward command
        commandCenter.seekForwardCommand.addTarget { [weak self] event in
            if let seekEvent = event as? MPSeekCommandEvent {
                self?.handleSeekForwardCommand(seconds: seekEvent.type == .beginSeeking ? 30 : 0)
            }
            return .success
        }
        
        // Seek backward command
        commandCenter.seekBackwardCommand.addTarget { [weak self] event in
            if let seekEvent = event as? MPSeekCommandEvent {
                self?.handleSeekBackwardCommand(seconds: seekEvent.type == .beginSeeking ? 15 : 0)
            }
            return .success
        }
        
        // Change playback position command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.handleChangePlaybackPositionCommand(time: positionEvent.positionTime)
            }
            return .success
        }
        
        // Configure skip intervals
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        
        // Enable commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.isEnabled = true
        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
    }
    
    // MARK: - Command Handlers
    
    private func handlePlayCommand() {
        NotificationCenter.default.post(
            name: Notification.Name("RemotePlayCommand"),
            object: nil
        )
    }
    
    private func handlePauseCommand() {
        NotificationCenter.default.post(
            name: Notification.Name("RemotePauseCommand"),
            object: nil
        )
    }
    
    private func handleSkipForwardCommand() {
        NotificationCenter.default.post(
            name: Notification.Name("RemoteSkipForwardCommand"),
            object: 30
        )
    }
    
    private func handleSkipBackwardCommand() {
        NotificationCenter.default.post(
            name: Notification.Name("RemoteSkipBackwardCommand"),
            object: 15
        )
    }
    
    private func handleSeekForwardCommand(seconds: TimeInterval) {
        NotificationCenter.default.post(
            name: Notification.Name("RemoteSeekForwardCommand"),
            object: seconds
        )
    }
    
    private func handleSeekBackwardCommand(seconds: TimeInterval) {
        NotificationCenter.default.post(
            name: Notification.Name("RemoteSeekBackwardCommand"),
            object: seconds
        )
    }
    
    private func handleChangePlaybackPositionCommand(time: TimeInterval) {
        NotificationCenter.default.post(
            name: Notification.Name("RemoteChangePlaybackPositionCommand"),
            object: time
        )
    }
    
    // MARK: - Now Playing Info
    
    func updateNowPlayingInfo(
        title: String,
        artist: String = "myBrain",
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        playbackRate: Float,
        artwork: MPMediaItemArtwork? = nil
    ) {
        var nowPlayingInfo: [String: Any] = [:]
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration.isFinite ? duration : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime.isFinite ? elapsedTime : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        
        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Audio Interruption Handling
    
    func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            NotificationCenter.default.post(
                name: Notification.Name("AudioInterruptionBegan"),
                object: nil
            )
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                NotificationCenter.default.post(
                    name: Notification.Name("AudioInterruptionEnded"),
                    object: options.contains(.shouldResume)
                )
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Audio Route Change Handling
    
    func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones were disconnected
            NotificationCenter.default.post(
                name: Notification.Name("AudioRouteDeviceDisconnected"),
                object: nil
            )
        case .newDeviceAvailable:
            // New audio device connected
            NotificationCenter.default.post(
                name: Notification.Name("AudioRouteDeviceConnected"),
                object: nil
            )
        default:
            break
        }
    }
}
