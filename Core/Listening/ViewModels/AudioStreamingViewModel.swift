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
        
        guard let streamingData = StreamingLinksResponseData(from: data),
              let masterPlaylist = streamingData.masterPlaylist else {
            print("🎵 Invalid streaming links response data")
            streamingState = .error(playerError ?? NSError(domain: "StreamingError", code: -1))
            playerError = NSError(domain: "StreamingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid streaming links data"])
            return
        }
        
        let fullURL = "\(NetworkConstants.baseURL)\(masterPlaylist)"
        
        print("🎵 Received streaming links:")
        print("🎵 Master playlist: \(fullURL)")
        
        if let audioPlaylist = streamingData.audioPlaylist {
            print("🎵 Audio playlist: \(NetworkConstants.baseURL)\(audioPlaylist)")
        }
        
        if let subtitlesPlaylist = streamingData.subtitlesPlaylist {
            let subtitlesURL = "\(NetworkConstants.baseURL)\(subtitlesPlaylist)"
            print("🎵 Subtitles playlist: \(subtitlesURL)")
            self.subtitlesURL = subtitlesURL
        }
        
        setupAudioPlayer(with: fullURL)
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
        
        // Update now playing info
        updateNowPlayingInfo()
        
        // Update subtitle timing - send current time to subtitle view
        NotificationCenter.default.post(
            name: Notification.Name("UpdateSubtitleTime"),
            object: currentSeconds
        )
        
        // Check if we need to request next chapter
        guard let nextChapterTime = nextChapterTime,
              currentSeconds >= (nextChapterTime - chapterBuffer),
              !nextChapterRequested else { return }
        
        nextChapterRequested = true
        requestNextChapter()
    }
    
    private func requestNextChapter() {
        guard let thoughtId = currentThought?.id else { return }
        networkService.webSocket.requestNextChapter(thoughtId: thoughtId, generateAudio: true)
    }
    
    private func handleChapterAudioResponse(data: [String: Any]?) {
        guard let chapterData = ChapterAudioResponseData(from: data),
              let chapterNumber = chapterData.chapterNumber,
              let audioDuration = chapterData.audioDuration else {
            print("🎵 Invalid chapter audio response data")
            return
        }
        
        let title = chapterData.title
        let generationTime = chapterData.generationTime
        
        print("🎵 Processing chapter \(chapterNumber): \(title ?? "Untitled")")
        print("🎵 Chapter duration: \(audioDuration)s, Generation time: \(generationTime ?? 0)s")
        
        let chapter = ChapterInfo(
            number: chapterNumber,
            title: title,
            duration: audioDuration,
            startTime: durationsSoFar,
            isComplete: false
        )
        
        chapterManager.addChapter(chapter)
        durationsSoFar += audioDuration
        
        // Calculate when to request next chapter (60s before this chapter ends)
        let chapterEndTime = chapter.startTime + audioDuration
        nextChapterTime = max(0, chapterEndTime - chapterBuffer)
        
        print("🎵 Chapter \(chapterNumber) added. Next chapter request at: \(nextChapterTime ?? 0)s")
        
        // Reset the flag so we can request the next chapter when needed
        nextChapterRequested = false
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

