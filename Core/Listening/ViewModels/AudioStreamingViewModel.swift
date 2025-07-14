import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioStreamingViewModel: ObservableObject {
    // MARK: - Audio Player State
    @Published var player: AVPlayer?
    @Published var masterPlaylistURL: URL?
    @Published var isPlaying = false
    @Published var isFetchingLinks = false
    @Published var playerError: Error?
    @Published var streamingState: AudioStreamingState = .idle
    
    // MARK: - Chapter Progress State
    @Published var currentChapterNumber: Int = 1
    @Published var nextChapterRequested = false
    @Published var lastChapterComplete = false
    @Published var hasCompletedPlayback = false
    @Published var nextChapterTime: Double?
    @Published var durationsSoFar: Double = 0.0
    
    // MARK: - Subtitle State
    @Published var subtitlesURL: String?
    
    // MARK: - Thought Context
    private var currentThought: Thought?
    
    // MARK: - Constants
    private let chapterBuffer: Double = 0.60 // Request next chapter 60s before current ends
    
    // MARK: - Dependencies
    private let networkService = NetworkServiceManager.shared
    private let backgroundManager = BackgroundManager.shared
    private let audioSessionManager = AudioSessionManager.shared
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    private var playbackProgressObserver: Any?
    private var playerItemObservation: AnyCancellable?
    private var startTime: Date?
    
    init() {
        setupWebSocketSubscriptions()
        setupRemoteControlHandlers()
    }
    
    deinit {
        Task { @MainActor in
            cleanupPlayer()
        }
    }
    
    // MARK: - Public Methods
    
    func startListening(for thought: Thought) {
        currentThought = thought
        hasCompletedPlayback = false
        resetState()
        fetchStreamingLinks(for: thought)
    }
    
    func pausePlayback() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resumePlayback() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }
    
    func cleanup() {
        cleanupPlayer()
        resetState()
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        currentChapterNumber = 1
        nextChapterRequested = false
        lastChapterComplete = false
        hasCompletedPlayback = false
        nextChapterTime = nil
        durationsSoFar = 0.0
        subtitlesURL = nil
        playerError = nil
    }
    
    private func fetchStreamingLinks(for thought: Thought) {
        isFetchingLinks = true
        streamingState = .fetchingLinks
        networkService.webSocket.sendStreamingLinks(thoughtId: thought.id)
    }
    
    private func setupWebSocketSubscriptions() {
        // Listen for streaming links response
        networkService.webSocket.messages
            .filter { message in
                switch message {
                case .response(let action, _):
                    return action == "streaming_links"
                default:
                    return false
                }
            }
            .sink { [weak self] message in
                switch message {
                case .response(_, let data):
                    self?.handleStreamingLinksResponse(data)
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Listen for chapter response
        networkService.webSocket.messages
            .filter { message in
                switch message {
                case .response(let action, _):
                    return action == "chapter_response"
                default:
                    return false
                }
            }
            .sink { [weak self] message in
                switch message {
                case .response(_, let data):
                    self?.handleChapterResponse(data)
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleStreamingLinksResponse(_ data: [String: Any]) {
        DispatchQueue.main.async {
            self.isFetchingLinks = false
            

            guard let masterPlaylistPath = data["master_playlist"] as? String else {
                let errorMessage = "master_playlist not found in response"
                self.playerError = NSError(
                    domain: "StreamingError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                print("Streaming links parsing error: \(errorMessage)")
                print("Received data: \(data)")
                return
            }
            
            let baseURL = "https://\(self.getBaseURL())"
            guard let url = URL(string: baseURL + masterPlaylistPath) else {
                let errorMessage = "Invalid URL: \(baseURL + masterPlaylistPath)"
                self.playerError = NSError(
                    domain: "StreamingError",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
                return
            }
            
            self.masterPlaylistURL = url
            
            // Setup subtitles if available
            if let subsPath = data["subtitles_playlist"] as? String, !subsPath.isEmpty {
                self.subtitlesURL = baseURL + subsPath
            }
            
            print("Successfully parsed streaming links - Master: \(url)")
            self.setupPlayer(with: url)
        }
    }
    
    private func setupPlayer(with url: URL) {
        cleanupPlayer()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        configurePlayerForBackground()
        
        isPlaying = true
        player?.play()
        startTime = Date()
        
        setupPlayerObservations()
    }
    
    private func configurePlayerForBackground() {
        audioSessionManager.activateAudioSession()
        
        // Enable background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupPlayerObservations() {
        guard let player = player else { return }
        
        // Observe player item status
        playerItemObservation = player.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .failed:
                    self?.playerError = player.currentItem?.error
                case .readyToPlay:
                    self?.updateNowPlayingInfo()
                default:
                    break
                }
            }
        
        // Monitor playback progress
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: 1),
            queue: .main
        ) { [weak self] currentTime in
            self?.monitorPlaybackProgress(currentTime: currentTime)
        }
        playbackProgressObserver = timeObserver
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackCompletion()
        }
    }
    
    private func monitorPlaybackProgress(currentTime: CMTime) {
        let currentSeconds = currentTime.seconds
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Check if we need to request next chapter
        guard let nextChapterTime = nextChapterTime,
              currentSeconds >= (nextChapterTime - chapterBuffer),
              !nextChapterRequested else { return }
        
        nextChapterRequested = true
        requestNextChapter()
    }
    
    private func requestNextChapter() {
        guard let thoughtId = currentThought?.id else { return }
        networkService.webSocket.sendNextChapter(thoughtId: thoughtId, generateAudio: true)
    }
    
    private func handleChapterResponse(_ data: [String: Any]) {
        DispatchQueue.main.async {
            let chapterNumber = data["chapter_number"] as? Int ?? 0
            let audioDuration = data["audio_duration"] as? Double ?? 0.0
            let generationTime = data["generation_time"] as? Double ?? 0.0
            let isComplete = data["complete"] as? Bool ?? false
            
            print("Chapter response - Number: \(chapterNumber), Duration: \(audioDuration), Complete: \(isComplete)")
            
            self.currentChapterNumber = chapterNumber
            
            if audioDuration > 0 {
                let playableDuration = audioDuration - generationTime
                self.nextChapterTime = self.durationsSoFar + (playableDuration * (1 - self.chapterBuffer))
                self.durationsSoFar += audioDuration
            }
            
            self.nextChapterRequested = false
            self.lastChapterComplete = isComplete
            
            // Refresh subtitles if available
            if let subtitlesURL = self.subtitlesURL {
                // Notify subtitle view model to refresh
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshSubtitles"),
                    object: subtitlesURL
                )
            }
        }
    }
    
    private func handlePlaybackCompletion() {
        DispatchQueue.main.async {
            if self.lastChapterComplete {
                self.hasCompletedPlayback = true
                self.isPlaying = false
                self.audioSessionManager.deactivateAudioSession()
            }
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let player = player,
              let currentItem = player.currentItem else { return }
        
        let currentTime = player.currentTime().seconds
        let duration = currentItem.duration.seconds
        
        audioSessionManager.updateNowPlayingInfo(
            title: currentThought?.name ?? "myBrain Audio",
            artist: "myBrain",
            duration: duration.isFinite ? duration : 0,
            elapsedTime: currentTime.isFinite ? currentTime : 0,
            playbackRate: isPlaying ? 1.0 : 0.0
        )
    }
    
    private func setupRemoteControlHandlers() {
        // Handle remote control commands from lock screen
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemotePlayCommand"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumePlayback()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemotePauseCommand"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pausePlayback()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemoteSkipForwardCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let seconds = notification.object as? TimeInterval {
                self?.skipForward(seconds: seconds)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemoteSkipBackwardCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let seconds = notification.object as? TimeInterval {
                self?.skipBackward(seconds: seconds)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemoteChangePlaybackPositionCommand"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let time = notification.object as? TimeInterval {
                self?.seekTo(time: time)
            }
        }
        
        // Handle audio interruptions
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioInterruptionBegan"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pausePlayback()
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioInterruptionEnded"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shouldResume = notification.object as? Bool, shouldResume {
                self?.resumePlayback()
            }
        }
        
        // Handle route changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioRouteDeviceDisconnected"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pausePlayback()
        }
    }
    
    private func skipForward(seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 1))
        
        if let duration = player.currentItem?.duration,
           duration.isValid && !duration.isIndefinite {
            let boundedTime = CMTimeMinimum(newTime, duration)
            player.seek(to: boundedTime)
        } else {
            player.seek(to: newTime)
        }
    }
    
    private func skipBackward(seconds: TimeInterval) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 1))
        let boundedTime = CMTimeMaximum(newTime, CMTime.zero)
        player.seek(to: boundedTime)
    }
    
    private func seekTo(time: TimeInterval) {
        guard let player = player else { return }
        let targetTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: targetTime)
    }
    
    private func cleanupPlayer() {
        player?.pause()
        
        if let observer = playbackProgressObserver {
            player?.removeTimeObserver(observer)
            playbackProgressObserver = nil
        }
        
        playerItemObservation?.cancel()
        playerItemObservation = nil
        
        NotificationCenter.default.removeObserver(self)
        
        player = nil
        masterPlaylistURL = nil
        streamingState = .idle
    }
    
    // MARK: - Helper Methods
    
    private func getBaseURL() -> String {
        // Extract base URL from network service
        return "brain.sorenapp.ir"
    }
}

