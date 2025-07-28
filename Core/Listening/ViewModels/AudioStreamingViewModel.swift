
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
    private var requestedChapters: Set<Int> = []
    @Published var currentChapterNumber: Int = 1
    
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
                self.subtitlesURL = "\(NetworkConstants.baseURL)\(subtitlesPlaylist)"
                print("🎵 Subtitles URL set: \(self.subtitlesURL!)")
            }
            
            DispatchQueue.main.async {
                self.setupPlayer(with: fullURL)
            }
        } else {
            streamingState = .error(NSError(domain: "StreamingError", code: -2))
        }
    }
    
    private func setupPlayer(with urlString: String) {
        guard let url = URL(string: urlString) else {
            streamingState = .error(NSError(domain: "InvalidURL", code: -1))
            return
        }
        
        masterPlaylistURL = url
        
        cleanupPlayer()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupPlayerObservations()
        configureAudioSession()
        
        streamingState = .ready
        startTime = Date()
        
        resumePlayback()
        
        if let subtitleURL = subtitlesURL {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NewChapterSubtitles"),
                    object: nil,
                    userInfo: [
                        "url": subtitleURL,
                        "offset": 0.0
                    ]
                )
            }
        }
    }
    
    private func cleanupPlayer() {
        if let observer = playbackProgressObserver {
            player?.removeTimeObserver(observer)
            playbackProgressObserver = nil
        }
        
        playerItemObservation?.cancel()
        playerItemObservation = nil
        
        player?.pause()
        player = nil
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func setupPlayerObservations() {
        guard let player = player else { return }
        
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
        
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] currentTime in
            Task { @MainActor in
                self?.monitorPlaybackProgress(currentTime: currentTime)
            }
        }
        playbackProgressObserver = timeObserver
        
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
        
        if let currentItem = player?.currentItem {
            let totalDuration = currentItem.duration.seconds
            self.duration = totalDuration.isFinite ? totalDuration : 0.0
        }
        
        chapterManager.updateCurrentChapter(for: currentSeconds)
        
        NotificationCenter.default.post(
            name: Notification.Name("UpdateSubtitleTime"),
            object: currentSeconds
        )
        
        checkForNextChapterRequest(currentTime: currentSeconds)
    }
    
    private func checkForNextChapterRequest(currentTime: Double) {
        guard let requestTime = nextChapterRequestTime else { return }
        
        let nextChapterNumber = currentChapterNumber + 1
        
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
        
        currentChapterNumber = chapterNumber
        
        let chapterStartTime = durationsSoFar
        
        let chapterInfo = ChapterInfo(
            number: chapterNumber,
            title: data["title"] as? String,
            duration: audioDuration,
            startTime: chapterStartTime,
            isComplete: isComplete
        )
        chapterManager.addChapter(chapterInfo)
        
        let requestDelay = audioDuration - generationTime
        nextChapterRequestTime = durationsSoFar + requestDelay
        
        durationsSoFar += audioDuration
        lastChapterComplete = isComplete
        
        print("🎵 Next chapter request time set to: \(nextChapterRequestTime ?? 0)")
        print("🎵 Total duration so far: \(durationsSoFar)")
        print("🎵 Chapter \(chapterNumber) starts at: \(chapterStartTime)")
        
        if let subtitleURL = subtitlesURL {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NewChapterSubtitles"),
                    object: nil,
                    userInfo: [
                        "url": subtitleURL,
                        "offset": chapterStartTime
                    ]
                )
            }
        }
    }
    
    private func handlePlaybackCompletion() {
        print("🎵 Playback completed - lastChapterComplete: \(lastChapterComplete)")
        
        DispatchQueue.main.async {
            if self.lastChapterComplete {
                self.hasCompletedPlayback = true
                self.isPlaying = false
            }
            else{
                print("🎵 ⚠️ Playback ended but more chapters expected")
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
    }
}
