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
    @Published var lastChapterComplete = false
    @Published var hasCompletedPlayback = false
    @Published var nextChapterRequestTime: Double?
    @Published var durationsSoFar: Double = 0.0
    
    // MARK: - Request Deduplication
    private var requestedChapters: Set<Int> = [] // Track requested chapters
    @Published var currentChapterNumber: Int = 1 // Track current chapter
    
    // MARK: - Subtitle State
    @Published var subtitlesURL: String?
    
    // MARK: - Thought Context
    private var currentThought: Thought?
    
    // MARK: - Dependencies
    private let networkService = NetworkServiceManager.shared
    private let backgroundManager = BackgroundManager.shared
    
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
    }
    
    func resumePlayback() {
        player?.play()
        isPlaying = true
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
        requestedChapters.removeAll()
        currentChapterNumber = 1
        lastChapterComplete = false
        hasCompletedPlayback = false
        nextChapterRequestTime = nil
        durationsSoFar = 0.0
        subtitlesURL = nil
        playerError = nil
        chapterManager.chapters.removeAll()
        chapterManager.currentChapter = nil
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
                print("❌ Streaming links error: \(message)")
                isFetchingLinks = false
                streamingState = .error(playerError ?? NSError(domain: "StreamingError", code: -1))
                playerError = NSError(domain: "StreamingError", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            
        case .chapterAudio(let status, let message, let data):
            print("🎵 Chapter audio response: \(status.rawValue) - \(message)")
            
            if status.isSuccess {
                handleChapterAudioResponse(data: data)
            } else {
                print("❌ Chapter audio error: \(message)")
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
        
        guard let data = data else {
            streamingState = .error(NSError(domain: "StreamingError", code: -1))
            return
        }
        
        if let masterPlaylist = data["master_playlist"] as? String {
            let fullURL = "\(NetworkConstants.baseURL)\(masterPlaylist)"
            
            if let subtitlesPlaylist = data["subtitles_playlist"] as? String {
                let subtitlesURL = "\(NetworkConstants.baseURL)\(subtitlesPlaylist)"
                self.subtitlesURL = subtitlesURL
            }
            
            setupAudioPlayer(with: fullURL)
        } else {
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
                    break
                default:
                    break
                }
            }
        
        // Monitor playback progress
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
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
        
        // Use currentSeconds directly (not globalTime) for chapter detection
        chapterManager.updateCurrentChapter(for: currentSeconds)
        
        // Send CURRENT chapter time, not global time
        NotificationCenter.default.post(
            name: Notification.Name("UpdateSubtitleTime"),
            object: currentSeconds
        )
        
        checkForNextChapterRequest(currentTime: currentSeconds)
    }
    
    private func checkForNextChapterRequest(currentTime: Double) {
        guard let requestTime = nextChapterRequestTime else { return }
        
        let nextChapterNumber = currentChapterNumber + 1
        
        // FIXED: Check if we should request the next chapter
        // Only request if: currentTime >= requestTime AND we haven't requested this chapter yet
        if currentTime >= requestTime && !requestedChapters.contains(nextChapterNumber) && !lastChapterComplete {
            requestedChapters.insert(nextChapterNumber)
            requestNextChapter()
            print("🎵 ✅ Requesting chapter \(nextChapterNumber) at time \(currentTime) (threshold: \(requestTime))")
        }
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
        
        print("🎵 Received chapter \(chapterNumber): duration=\(audioDuration)s, generation=\(generationTime)s")
        
        // FIXED: Update current chapter number
        currentChapterNumber = chapterNumber
                
        // Add chapter to manager
        let chapterInfo = ChapterInfo(
            number: chapterNumber,
            title: data["title"] as? String,
            duration: audioDuration,
            startTime: durationsSoFar,
            isComplete: isComplete
        )
        chapterManager.addChapter(chapterInfo)
        
        // FIXED: Calculate when to request next chapter using generation_time (restored from old approach)
        // Request next chapter at: (current_chapter_duration - generation_time) seconds into current chapter
        let requestDelay = audioDuration - generationTime
        nextChapterRequestTime = durationsSoFar + requestDelay
        
        // Update accumulated durations
        durationsSoFar += audioDuration
        lastChapterComplete = isComplete
        
        print("🎵 Next chapter request time set to: \(nextChapterRequestTime ?? 0)")
        print("🎵 Total duration so far: \(durationsSoFar)")
        
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
            }
        }
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

