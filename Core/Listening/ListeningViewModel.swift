import Foundation
import AVFoundation
import Combine
import MediaPlayer
import NaturalLanguage

@MainActor
class ListeningViewModel: ObservableObject {
    // MARK: - Audio Player State
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isFetchingLinks = false
    @Published var playerError: Error?
    @Published var listeningState: ListeningState = .idle
    @Published var chapterManager = ChapterManager()
    
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    
    // MARK: - Chapter Progress State
    @Published var lastChapterComplete = false
    @Published var hasCompletedAllChapters = false
    @Published var nextChapterRequestTime: Double?
    @Published var durationsSoFar: Double = 0.0
    
    // MARK: - Subtitle
    @Published var paragraphs: [[WordData]] = []
    @Published var allWords: [WordTimestamp] = []
    @Published var currentWordIndex: Int = -1
    private var lastUpdateTime: TimeInterval = -1
    
    // MARK: - Request Deduplication
    private var requestedChapters: Set<Int> = []
    @Published var currentChapterNumber: Int = 1
    private var pendingChapterWords: [[String: Any]] = []
    @Published var isCurrentlyStalled = false

    // MARK: - Thought Context
    private var currentThought: Thought?
        
    // MARK: - Private State
    private var didEndToken: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var playbackProgressObserver: Any?
    private var playerItemObservation: AnyCancellable?
    private var timeControlObs: AnyCancellable?
    private var accessLogObs: AnyCancellable?
    private var searchIndex: Int = 0
    private var wordStarts: [Double] = []
    
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
    
    func buildParagraphs() {
        let allText = allWords.map { $0.text }.joined(separator: " ")
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = allText
        
        let commonUppercaseWords: Set<String> = ["I", "I'm", "I'll", "I've", "I'd", "Dr", "Mr", "Mrs", "Ms"]
        
        var currentParagraph: [WordData] = []
        var newParagraphs: [[WordData]] = []
        var textIndex = allText.startIndex
        
        for (index, wordTimestamp) in allWords.enumerated() {
            let wordData = WordData(
                originalIndex: index,
                text: wordTimestamp.text,
                startTime: wordTimestamp.start,
                endTime: wordTimestamp.end
            )
            
            let word = wordTimestamp.text
            let firstChar = word.first
            let isUppercase = firstChar?.isUppercase == true
            
            if let wordRange = allText.range(of: word, range: textIndex..<allText.endIndex) {
                var shouldStartNewParagraph = false
                
                if isUppercase && !currentParagraph.isEmpty {
                    if !commonUppercaseWords.contains(word) {
                        tagger.enumerateTags(in: wordRange, unit: .word, scheme: .nameType) { tag, _ in
                            shouldStartNewParagraph = !(tag == .personalName || tag == .placeName || tag == .organizationName)
                            return false
                        }
                        
                        if shouldStartNewParagraph {
                            tagger.enumerateTags(in: wordRange, unit: .word, scheme: .lexicalClass) { tag, _ in
                                if tag == .noun && word.count > 3 {
                                    shouldStartNewParagraph = false
                                }
                                return false
                            }
                        }
                    }
                }
                
                if shouldStartNewParagraph {
                    newParagraphs.append(currentParagraph)
                    currentParagraph = []
                }
                
                textIndex = wordRange.upperBound
            }
            
            currentParagraph.append(wordData)
        }
        
        if !currentParagraph.isEmpty {
            newParagraphs.append(currentParagraph)
        }
        
        paragraphs = newParagraphs
    }

    
    func startListening(for thought: Thought) {
        currentThought = thought
        hasCompletedAllChapters = false
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
        hasCompletedAllChapters = false
        nextChapterRequestTime = nil
        durationsSoFar = 0.0
        playerError = nil
        chapterManager.chapters.removeAll()
        chapterManager.currentChapter = nil
        pendingChapterWords.removeAll()
        allWords.removeAll()
        paragraphs = []
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
                hasCompletedAllChapters = true
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
        
        cleanupPlayer()
        
        configureAudioSession()
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        setupPlayerObservations()
        
        listeningState = .ready
        
        isPlaying = true
        player?.playImmediately(atRate: 1.0)
                
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
            wordStarts = allWords.map { $0.start }
            if currentWordIndex >= 0 { searchIndex = currentWordIndex }
            else { searchIndex = min(searchIndex, max(allWords.count - 1, 0)) }
            
            buildParagraphs()

            print("🎵 Total words now: \(allWords.count)")
            print("🎵 First word: \(allWords.first?.text ?? "none"), Last word: \(allWords.last?.text ?? "none")")
            
            if !newWords.isEmpty {
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
    
    func updateCurrentTime(_ t: Double) {
        // keep the existing 50ms gate if you like
        guard abs(t - lastUpdateTime) > 0.08 else { return }
        lastUpdateTime = t
        guard !allWords.isEmpty else { return }

        // fast path: advance forward
        var i = min(searchIndex, allWords.count - 1)
        if t >= allWords[i].end {
            // walk forward until we enclose t or pass it
            while i + 1 < allWords.count, t >= allWords[i].end { i += 1 }
            if allWords[i].start <= t, t <= allWords[i].end {
                applyIndexIfChanged(i, at: t); return
            }
            // overshot t → fall back to local binary search around i
        } else if t < allWords[i].start {
            // time moved backwards (scrub/seek) → binary search
            i = insertionIndex(in: wordStarts, for: t)
            i = max(0, min(i, allWords.count - 1))
        }
        // small local window scan around i
        let lo = max(0, i - 2), hi = min(allWords.count - 1, i + 2)
        for j in lo...hi {
            let w = allWords[j]
            if (w.start == w.end && abs(t - w.start) < 0.08) || (t >= w.start && t <= w.end) {
                applyIndexIfChanged(j, at: t); return
            }
        }
        // no change
    }

    @inline(__always)
    private func insertionIndex(in sorted: [Double], for x: Double) -> Int {
        var l = 0, r = sorted.count
        while l < r {
            let m = (l + r) >> 1
            if sorted[m] < x { l = m + 1 } else { r = m }
        }
        return l
    }

    @inline(__always)
    private func applyIndexIfChanged(_ idx: Int, at t: Double) {
        let prev = currentWordIndex
        if idx != prev {
            currentWordIndex = idx
            // emit feedback only when index changed (existing logic)
            if idx >= 0, idx < allWords.count, let thoughtId = currentThought?.id {
                let word = allWords[idx].text
                let chapterNum = chapterManager.currentChapter?.number ?? currentChapterNumber
                let v = bluetoothService.processFeedback(word: word)
                feedbackBuffer.addFeedback(word: word, value: v, thoughtId: thoughtId, chapterNumber: chapterNum)
            }
        }
    }
    
    
    private func cleanupPlayer() {
        if let observer = playbackProgressObserver {
            player?.removeTimeObserver(observer)
            playbackProgressObserver = nil
        }
        
        if let token = didEndToken {
            NotificationCenter.default.removeObserver(token)
            didEndToken = nil
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
                if status == .readyToPlay, self?.isPlaying == true {
                    self?.player?.play()
                }
            }
        
        timeControlObs = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                if self.isPlaying, status != .playing {
                    self.player?.play()
                }
            }
        
        accessLogObs = NotificationCenter.default.publisher(
            for: .AVPlayerItemNewAccessLogEntry,
            object: player.currentItem
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            if self?.isPlaying == true { self?.player?.play() }
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
        
        didEndToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackCompletion()
            }
        }
        
        NotificationCenter.default.publisher(for: AVPlayerItem.playbackStalledNotification)
            .sink { [weak self] _ in
                print("🎵 Playback stalled (likely waiting for next chapter)")
                self?.isCurrentlyStalled = true
            }
            .store(in: &cancellables)
    }
    
    private func monitorPlaybackProgress(currentTime: CMTime) {
        let currentSeconds = currentTime.seconds
        self.currentTime = currentSeconds.isFinite ? currentSeconds : 0.0
        
        if let currentItem = player?.currentItem {
            let totalDuration = currentItem.duration.seconds
            self.duration = totalDuration.isFinite ? totalDuration : 0.0
            
            if totalDuration > 0 && currentSeconds >= totalDuration - 1.0 {
                let nextChapterNumber = currentChapterNumber + 1
                if !requestedChapters.contains(nextChapterNumber) &&
                   (nextChapterRequestTime == nil || currentSeconds > nextChapterRequestTime! + 10.0) {
                    lastChapterComplete = true
                    hasCompletedAllChapters = true
                    print("🎵 Reached end of audio - marking as complete")
                }
            }
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
            
            let requestDelay = max(audioDuration - generationTime * 2 , 5.0)
            nextChapterRequestTime = durationsSoFar + requestDelay
            durationsSoFar += audioDuration
            
            if let isLast = data["is_last"] as? Bool, isLast {
                lastChapterComplete = true
                print("🎵 This is the last chapter - will complete after playback")
            }
        }
        
        if let words = chapterAudioData.words {
            let adjustedWords = words.compactMap { wordData -> [String: Any]? in
                guard let text = wordData["text"] as? String,
                      let start = wordData["start"] as? Double,
                      let end = wordData["end"] as? Double else {
                    return nil
                }
                
                let chapterOffset = durationsSoFar - (chapterAudioData.audioDuration ?? 0.0)
                
                return [
                    "text": text,
                    "start": start + chapterOffset,
                    "end": end + chapterOffset
                ]
            }

            if player != nil {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("NewChapterWordsFromAudio"),
                        object: nil,
                        userInfo: ["words": adjustedWords]
                    )
                }
            } else {
                pendingChapterWords = adjustedWords
            }
        }

        if let player = player,
           isPlaying,
           isCurrentlyStalled {
            print("🎵 Player is stalled but new chapter \(receivedChapterNumber) is ready, resuming playback...")
            
            isCurrentlyStalled = false
                        
            player.play()
            
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
                                self.isCurrentlyStalled = false
                            } else {
                                print("🎵 ⚠️ Playback still stalled - HLS might need more time to update")
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    
    private func handlePlaybackCompletion() {
        DispatchQueue.main.async {
            if self.lastChapterComplete {
                self.hasCompletedAllChapters = true
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
