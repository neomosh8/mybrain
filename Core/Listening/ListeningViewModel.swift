
import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class ListeningViewModel: ObservableObject {
    // MARK: - Audio Player State
    @Published var player: AVPlayer?
    @Published var masterPlaylistURL: URL?
    @Published var isPlaying = false
    @Published var isFetchingLinks = false
    @Published var playerError: Error?
    @Published var listeningState: ListeningState = .idle
    @Published var chapterManager = ChapterManager()
    
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    
    // MARK: - Chapter Progress State
    @Published var lastChapterComplete = false
    @Published var hasCompletedPlayback = false
    @Published var nextChapterRequestTime: Double?
    @Published var durationsSoFar: Double = 0.0
    
    // MARK: - Subtitle
    @Published var allWords: [WordTimestamp] = []
    @Published var currentWordIndex: Int = -1
    private var lastUpdateTime: TimeInterval = -1
    
    // MARK: - Request Deduplication
    private var requestedChapters: Set<Int> = []
    @Published var currentChapterNumber: Int = 1
    private var pendingChapterWords: [[String: Any]] = []
    private var isCurrentlyStalled = false
    
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
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ResumePlaybackAfterGap"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in                
                self?.player?.play()
                self?.isPlaying = true
            }
        }
    }
    
    //    deinit {
    //        cleanup()
    //    }
    
    // MARK: - Public Interface
    
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
        playerError = nil
        chapterManager.chapters.removeAll()
        chapterManager.currentChapter = nil
        pendingChapterWords.removeAll() // Add this line
    }
    
    private func fetchStreamingLinks(for thought: Thought) {
        isFetchingLinks = true
        listeningState = .fetchingLinks
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
            if status.isSuccess {
                handleStreamingLinksResponse(data: data)
            } else {
                isFetchingLinks = false
                listeningState = .error(playerError ?? NSError(domain: "ListeningError", code: -1))
                playerError = NSError(domain: "ListeningError", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
            
        case .chapterAudio(let status, _, let data):
            if status.isSuccess {
                handleChapterAudioResponse(data: data)
            }
            
        case .chapterComplete(_, _, let data):
            if let completeData = ChapterCompleteResponseData(from: data),
               let complete = completeData.complete,
               complete {
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
            listeningState = .error(NSError(domain: "ListeningError", code: -1))
            return
        }
        
        if let masterPlaylist = data["master_playlist"] as? String {
            let fullURL = "\(NetworkConstants.baseURL)\(masterPlaylist)"
            
            DispatchQueue.main.async {
                self.setupPlayer(with: fullURL)
            }
        } else {
            listeningState = .error(NSError(domain: "ListeningError", code: -2))
        }
    }
    
    private func setupPlayer(with urlString: String) {
        guard let url = URL(string: urlString) else {
            listeningState = .error(NSError(domain: "InvalidURL", code: -1))
            return
        }
        
        masterPlaylistURL = url
        
        cleanupPlayer()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        setupPlayerObservations()
        configureAudioSession()
        
        listeningState = .ready
        startTime = Date()
        
        resumePlayback()
        
        // Send any pending words now that player is ready
        if !pendingChapterWords.isEmpty {
            print("🎵 Sending \(pendingChapterWords.count) pending words from Chapter 1")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("NewChapterWordsFromAudio"),
                    object: nil,
                    userInfo: ["words": self.pendingChapterWords]
                )
                self.pendingChapterWords.removeAll()
            }
        }
    }
    
    func loadWordsFromChapterAudio(words: [[String: Any]]) {
        let newWords = words.compactMap { wordData -> WordTimestamp? in
            guard let text = wordData["text"] as? String,
                  let start = wordData["start"] as? Double,
                  let end = wordData["end"] as? Double else {
                return nil
            }
            
            let adjustedEnd = max(end, start + 0.3)
            return WordTimestamp(start: start, end: adjustedEnd, text: text)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.appendNewWords(newWords)
        }
    }
    
    private func appendNewWords(_ newWords: [WordTimestamp]) {
        print("🎵 appendNewWords called with \(newWords.count) words")
        
        if !newWords.isEmpty {
            allWords.append(contentsOf: newWords)
            allWords.sort { $0.start < $1.start }
            
            print("🎵 Total words now: \(allWords.count)")
            print("🎵 First word: \(allWords.first?.text ?? "none"), Last word: \(allWords.last?.text ?? "none")")
            
            if newWords.first != nil {
                lastUpdateTime = -1
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("ResumePlaybackAfterGap"),
                        object: nil
                    )
                }
                
            }
        }
    }
    
    func updateCurrentTime(_ globalTime: Double) {
        guard abs(globalTime - lastUpdateTime) > 0.05 else { return }
        lastUpdateTime = globalTime
        
        let previousWordIndex = currentWordIndex
        
        let newIndex = allWords.firstIndex { word in
            if word.start == word.end {
                return abs(globalTime - word.start) < 0.05
            } else {
                return globalTime >= word.start && globalTime <= word.end
            }
        }
        
        currentWordIndex = newIndex ?? previousWordIndex
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
        
        NotificationCenter.default.publisher(for: AVPlayerItem.playbackStalledNotification)
            .sink { _ in
                print("🎵 Playback stalled (likely waiting for next chapter)")
                self.isCurrentlyStalled = true
            }
            .store(in: &cancellables)

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
        guard let data = data,
              let chapterAudioData = ChapterAudioResponseData(from: data) else {
            print("❌ Failed to parse chapter_audio data")
            return
        }
        
        let receivedChapterNumber = chapterAudioData.chapterNumber ?? 0

        // Handle chapter info
        if let chapterNumber = chapterAudioData.chapterNumber {
            let audioDuration = chapterAudioData.audioDuration ?? 0.0
            let generationTime = chapterAudioData.generationTime ?? 0.0
            let title = chapterAudioData.title ?? ""
            let chapterStartTime = durationsSoFar
            
            print("🎵 Chapter \(chapterNumber) audio generated")
            currentChapterNumber = chapterNumber
            
            let chapterInfo = ChapterInfo(
                number: chapterNumber,
                title: title,
                duration: audioDuration,
                startTime: chapterStartTime
            )
            chapterManager.addChapter(chapterInfo)
            
            let requestDelay = audioDuration - generationTime
            nextChapterRequestTime = durationsSoFar + requestDelay
            durationsSoFar += audioDuration
        }
        
        if let words = chapterAudioData.words {
            print("🎵 Sending \(words.count) words to subtitle system")
            // Adjust word timings to account for previous chapters
            let adjustedWords = words.compactMap { wordData -> [String: Any]? in
                guard let text = wordData["text"] as? String,
                      let start = wordData["start"] as? Double,
                      let end = wordData["end"] as? Double else {
                    return nil
                }
                
                // Add the chapter offset to word timings
                let chapterOffset = durationsSoFar - (chapterAudioData.audioDuration ?? 0.0)
                
                return [
                    "text": text,
                    "start": start + chapterOffset,
                    "end": end + chapterOffset
                ]
            }
            // If player is ready, send immediately
            if player != nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("NewChapterWordsFromAudio"),
                        object: nil,
                        userInfo: ["words": adjustedWords]
                    )
                }
            } else {
                // Store for later when player is ready
                print("🎵 Player not ready, storing words for later")
                pendingChapterWords = adjustedWords
            }
        }
        
        print("🎵 Debug - Player exists: \(player != nil)")
        print("🎵 Debug - isPlaying: \(isPlaying)")
        print("🎵 Debug - isCurrentlyStalled: \(isCurrentlyStalled)")
        if let player = player {
            print("🎵 Debug - Player rate: \(player.rate)")
        }

        if let player = player,
           isPlaying,
           isCurrentlyStalled {
            print("🎵 Player is stalled but new chapter \(receivedChapterNumber) is ready, resuming playback...")
            
            isCurrentlyStalled = false
            
            print("🎵 Forcing playback to continue...")
            
            player.play()
            
            // If the player is truly stuck, we might need to nudge it
            // by pausing and immediately playing again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self,
                      self.isPlaying,
                      let player = self.player else { return }
                
                if player.rate == 0 {
                    print("🎵 Player still stalled, trying pause/play cycle...")
                    player.pause()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        player.play()
                        self.isPlaying = true
                        
                        // Final verification
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if player.rate > 0 {
                                print("🎵 ✅ Playback successfully resumed")
                            } else {
                                print("🎵 ⚠️ Playback still stalled - HLS might need more time to update")
                            }
                        }
                    }
                } else {
                    print("🎵 ✅ Playback resumed successfully")
                }
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
