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
    @Published var chapterManager = ChapterManager()
    
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0

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
        networkService.webSocket.requestStreamingLinks(thoughtId: thought.id)
    }
    
    private func setupWebSocketSubscriptions() {
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .streamingLinksResponse(let status, let message, let data):
            print("🎵 Streaming links response: \(status.rawValue) - \(message)")
            
            if status.isSuccess {
                handleStreamingLinksResponse(data: data)
            } else {
                print("🎵 Streaming links error: \(message)")
                isFetchingLinks = false
                streamingState = .error(playerError ?? NSError(domain: "StreamingError", code: -1))
                playerError = NSError(domain: "StreamingError", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            
        case .chapterAudio(let status, let message, let data):
            print("🎵 Chapter audio response: \(status.rawValue) - \(message)")
            
            if status.isSuccess {
                handleChapterAudioResponse(data: data)
            } else {
                print("🎵 Chapter audio error: \(message)")
            }
            
        case .chapterComplete(_, let message, let data):
            print("🎵 Chapter complete: \(message)")
            
            if let completeData = ChapterCompleteResponseData(from: data),
               let complete = completeData.complete,
               complete {
                print("🎵 All chapters completed")
                lastChapterComplete = true
                hasCompletedPlayback = true
            }
            
        default:
            break
        }
    }
    
    
    private func handleStreamingLinksResponse(data: [String: Any]?) {
        isFetchingLinks = false
        
        // Debug: Print the actual data received
        print("🎵 Raw streaming data received: \(String(describing: data))")
        
        guard let data = data else {
            print("🎵 No data in streaming response")
            streamingState = .error(NSError(domain: "StreamingError", code: -1))
            return
        }
        
        // Try direct access first (without using the struct)
        if let masterPlaylist = data["master_playlist"] as? String {
            let fullURL = "\(NetworkConstants.baseURL)\(masterPlaylist)"
            print("🎵 Direct access - Master playlist: \(fullURL)")
            
            if let subtitlesPlaylist = data["subtitles_playlist"] as? String {
                let subtitlesURL = "\(NetworkConstants.baseURL)\(subtitlesPlaylist)"
                self.subtitlesURL = subtitlesURL
            }
            
            setupAudioPlayer(with: fullURL)
        } else {
            print("🎵 No master_playlist found in data keys: \(data.keys)")
            streamingState = .error(NSError(domain: "StreamingError", code: -1))
        }
    }
    
    private func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        streamingState = .ready
        setupPlayerObservations()
        configurePlayerForBackground() 
    }
    
    private func setupAudioPlayer(with url: String) {
        cleanupPlayer()
        
        guard let playerURL = URL(string: url) else { return }
        let playerItem = AVPlayerItem(url: playerURL)
        player = AVPlayer(playerItem: playerItem)
        
        configurePlayerForBackground()
        
        isPlaying = true
        player?.play()
        startTime = Date()
        
        setupPlayerObservations()
        
        // Send subtitle notification AFTER player setup
        if let subtitleURL = subtitlesURL {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("InitialSubtitleLoad"),
                    object: ["url": subtitleURL]
                )
            }
        }
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
            Task { @MainActor in
                self?.monitorPlaybackProgress(currentTime: currentTime)
            }
        }
        playbackProgressObserver = timeObserver
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackCompletion()
            }
        }
    }
    
    private func monitorPlaybackProgress(currentTime: CMTime) {
        let currentSeconds = currentTime.seconds
        self.currentTime = currentSeconds.isFinite ? currentSeconds : 0.0
        
        // Update duration if available
        if let currentItem = player?.currentItem {
            let totalDuration = currentItem.duration.seconds
            self.duration = totalDuration.isFinite ? totalDuration : 0.0
        }
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Send CURRENT chapter time, not global time
        NotificationCenter.default.post(
            name: Notification.Name("UpdateSubtitleTime"),
            object: currentSeconds
        )
        
        // Check if we need to request next chapter using global time
        let globalTime = currentSeconds + durationsSoFar
        guard let nextChapterTime = nextChapterTime,
              globalTime >= (nextChapterTime - chapterBuffer),
              !nextChapterRequested else { return }
        
        nextChapterRequested = true
        requestNextChapter()
    }
    
    private func requestNextChapter() {
        guard let thoughtId = currentThought?.id else { return }
        networkService.webSocket.requestNextChapter(thoughtId: thoughtId, generateAudio: true)
    }
    
    private func handleChapterAudioResponse(data: [String: Any]?) {
        guard let data = data else {
            print("🎵 No chapter data received")
            return
        }
        
        let chapterNumber = data["chapter_number"] as? Int ?? 0
        let audioDuration = data["audio_duration"] as? Double ?? 0.0
        let generationTime = data["generation_time"] as? Double ?? 0.0
        let isComplete = data["complete"] as? Bool ?? false
        
        currentChapterNumber = chapterNumber
        
        let playableDuration = audioDuration - generationTime
        nextChapterTime = durationsSoFar + (playableDuration * (1 - chapterBuffer))
        
        nextChapterRequested = false
        durationsSoFar += audioDuration
        lastChapterComplete = isComplete
        
        print("🎵 Chapter \(chapterNumber) completed. Total duration so far: \(durationsSoFar)")
        
        // Refresh subtitles for new chapter if subtitle URL exists
        if let subtitleURL = subtitlesURL {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("RefreshSubtitles"),
                    object: ["url": subtitleURL]
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
            Task { @MainActor in
                self?.resumePlayback()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RemotePauseCommand"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pausePlayback()
            }
        }
        
        // Handle audio interruptions
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioInterruptionBegan"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pausePlayback()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioInterruptionEnded"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shouldResume = notification.object as? Bool, shouldResume {
                Task { @MainActor in
                    self?.resumePlayback()
                }
            }
        }
        
        // Handle route changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioRouteDeviceDisconnected"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pausePlayback()
            }
        }
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
}

