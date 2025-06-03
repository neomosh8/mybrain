import SwiftUI
import AVKit
import Combine
import MediaPlayer

struct StreamThoughtView: View {
    let thought: Thought
    let webSocketService: WebSocketService & ThoughtWebSocketService
    
    @EnvironmentObject var backgroundManager: BackgroundManager
    
    @State private var player: AVPlayer?
    @State private var playerError: Error?
    @State private var isFetchingLinks = false
    @State private var masterPlaylistURL: URL?
    
    @State private var nextChapterRequested = false
    @State private var playerItemObservation: AnyCancellable?
    @State private var playbackProgressObserver: Any?
    @State private var currentChapterNumber: Int = 1
    @State private var durations_so_far: Double = 0.0
    
    @State private var lastCheckTime: Double = 0.0
    @State private var startTime: Date?
    @State private var isPlaying = false
    @State private var lastChapterComplete = false
    @State private var hasCompletedPlayback = false
    
    /// Time in seconds after which we request the next chapter.
    @State private var nextChapterTime: Double? = nil
    
    /// Buffer factor so we can request the next chapter slightly before the current one ends.
    private let buffer: Double = 0.60
    
    // Subtitles
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    @State private var subsUrlStr: String?
    
    // Cancellables for subscriptions
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        // ------------------------------------------
        // Wrap our main stream UI inside ThoughtNavigationView
        // ------------------------------------------
        ThoughtNavigationView(
            thought: thought,
            webSocketService: webSocketService
        ) {
            // The MAIN content for streaming, shown once user chooses "Resume" or if brand new
            ZStack {
                Color.clear.ignoresSafeArea()
                
                
                if hasCompletedPlayback {
                    ChapterCompletionView(
                        webSocketService: webSocketService,
                        thoughtId: thought.id
                    )
                } else {
                    VStack {
                        if isFetchingLinks {
                            ProgressView("Fetching Streaming Links...")
                        } else if let player = player {
                            // Audio controls only
                            audioPlayerControls
                            
                            // Show Subtitles
                            SubtitleView(
                                viewModel: subtitleViewModel,
                                thoughtId: thought.id,
                                chapterNumber: $currentChapterNumber,
                                webSocketService: webSocketService
                            )
                        } else if let error = playerError {
                            Text("Player Error: \(error.localizedDescription)")
                                .foregroundColor(.red)
                        } else {
                            Text("Ready to Stream \(thought.name)")
                                .foregroundColor(.black)
                        }
                    }
                    .padding()
                }
            }
        }
        // ------------------------------------------
        // Provide closures for resume and reset
        // ------------------------------------------
        .onResume {
            // Called when user picks "Resume" in the overlay (if in_progress)
            // or after "not_started" with no prompt needed.
            fetchStreamingLinks()
        }
        .onResetFinished {
            // Called when user picks "Restart From Beginning" and server reset is successful
            // We can clear out relevant local state, then fetch fresh streaming links:
            durations_so_far = 0
            nextChapterTime = nil
            fetchStreamingLinks()
        }
        .onAppear {
            // Set up notification observer for playback state changes
            let notificationPublisher = NotificationCenter.default.publisher(
                for: NSNotification.Name("PlaybackStateChanged")
            )
            
            notificationPublisher
                .sink { notification in
                    if let isPlaying = notification.userInfo?["isPlaying"] as? Bool {
                        self.isPlaying = isPlaying
                        if isPlaying {
                            self.updateNowPlayingInfo()
                        }
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to chapter responses
            webSocketService.messagePublisher
                .filter { $0["type"] as? String == "chapter_response" }
                .sink { message in
                    self.handleNextChapterResponse(message: message)
                }
                .store(in: &cancellables)
            
            // Subscribe to streaming links responses
            webSocketService.messagePublisher
                .filter { $0["type"] as? String == "streaming_links" }
                .sink { message in
                    self.handleStreamingLinksResponse(message: message)
                }
                .store(in: &cancellables)
            
            setupInterruptionHandlers()
            setupRouteChangeHandlers()
        }
        .onDisappear {
            player?.pause()
            cleanupBackgroundPlayback()
            player = nil
            masterPlaylistURL = nil
            playerItemObservation?.cancel()
            if let observer = playbackProgressObserver {
                player?.removeTimeObserver(observer)
            }
            playbackProgressObserver = nil
            cancellables = Set<AnyCancellable>()
        }
    }
    
    // MARK: - Audio Player Controls
    private var audioPlayerControls: some View {
        HStack {
            Button(action: {
                if isPlaying {
                    player?.pause()
                } else {
                    player?.play()
                }
                isPlaying.toggle()
                
                updateNowPlayingInfo()
            }) {
                Image(
                    systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.system(size: 40))
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Fetch Streaming
    func fetchStreamingLinks() {
        hasCompletedPlayback = false
        isFetchingLinks = true
        
        webSocketService.configureForBackgroundOperation()
        webSocketService.requestStreamingLinks(thoughtId: thought.id)
    }
    
    private func handleStreamingLinksResponse(message: [String: Any]) {
        isFetchingLinks = false
        
        guard let status = message["status"] as? String,
              status == "success",
              let data = message["data"] as? [String: Any],
              let masterPlaylistPath = data["master_playlist"] as? String
        else {
            let errorMessage = message["message"] as? String ?? "Failed to get the streaming URLs"
            playerError = NSError(
                domain: "StreamingError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            return
        }
        
        let baseURL = "https://\(baseUrlFromWebSocketService())"
        guard let url = URL(string: baseURL + masterPlaylistPath) else {
            let errorMessage = "Invalid URL: \(baseURL + masterPlaylistPath)"
            playerError = NSError(
                domain: "StreamingError",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            return
        }
        masterPlaylistURL = url
        
        // Check if we have subtitles
        if let subsPath = data["subtitles_playlist"] as? String, !subsPath.isEmpty {
            let subsUrlStr = baseURL + subsPath
            self.subsUrlStr = subsUrlStr
            fetchSubtitlePlaylist(playlistURL: subsUrlStr)
        }
        
        setupPlayer(url: url)
    }
    
    // Helper to extract base URL from the WebSocketService
    private func baseUrlFromWebSocketService() -> String {
        // Try to get the base URL from the service if it's a WebSocketManager or ServerConnect
        // For now just return a default
        return "brain.sorenapp.ir"
    }
    
    // MARK: - Setup Player
    func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        configurePlayerForBackground()
        
        isPlaying = true
        player?.play()
        startTime = Date()
        
        if playerItemObservation == nil {
            playerItemObservation = player?
                .publisher(for: \.currentItem?.status)
                .compactMap { $0 }
                .sink { status in
                    if status == .readyToPlay {
                        self.startPlaybackProgressObservation()
                        
                        self.updateNowPlayingInfo()
                    }
                }
        }
    }
    
    func startPlaybackProgressObservation() {
        guard let player = player else { return }
        
        player.publisher(for: \.currentItem?.status)
            .compactMap { $0 }
            .filter { $0 == .readyToPlay }
            .sink { _ in
                // Set up notification for when playback ends
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: self.player?.currentItem,
                    queue: .main
                ) { _ in
                    // If this was the last chapter, show completion view
                    if self.lastChapterComplete {
                        withAnimation {
                            self.hasCompletedPlayback = true
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        
        let interval = CMTime(
            seconds: 0.1,
            preferredTimescale: CMTimeScale(NSEC_PER_SEC)
        )
        playbackProgressObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            let currentTime = time.seconds
            self.checkPlaybackProgress(currentTime: currentTime)
            // Update subtitle time
            self.subtitleViewModel.updateCurrentTime(currentTime)
            // Adjust for segment boundary
            self.subtitleViewModel.checkSegmentBoundary { newIndex in
                self.subtitleViewModel.loadSegment(at: newIndex)
            }
            
            
            
            // Update now playing info every 5 seconds to keep it current
            if Int(currentTime) % 5 == 0 {
                self.updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - Check Progress & Request Next Chapter
    func checkPlaybackProgress(currentTime: Double) {
        guard let nextChapterTime = nextChapterTime, !nextChapterRequested else {
            return
        }
        if currentTime >= nextChapterTime {
            nextChapterRequested = true
            
            if lastChapterComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        self.hasCompletedPlayback = true
                    }
                }
            } else {
                requestNextChapter()
            }
        }
    }
    
    func requestNextChapter() {
        webSocketService
            .requestNextChapter(thoughtId: thought.id, generateAudio: true)
    }
    
    // MARK: - Handle Next Chapter
    func handleNextChapterResponse(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any] else { return }
        
        let chapterNumber = data["chapter_number"] as? Int ?? 0
        let audioDuration = data["audio_duration"] as? Double ?? 0.0
        let generationTime = data["generation_time"] as? Double ?? 0.0
        let isComplete = data["complete"] as? Bool ?? false
        
        currentChapterNumber = chapterNumber
        
        let playableDuration = audioDuration - generationTime
        nextChapterTime = durations_so_far + (playableDuration * (1 - buffer))
        
        nextChapterRequested = false
        durations_so_far += audioDuration
        lastChapterComplete = isComplete
        
        // Re‐fetch updated subtitles
        if let subsUrlStr = subsUrlStr {
            fetchSubtitlePlaylist(playlistURL: subsUrlStr)
        }
    }
    
    // MARK: - Subtitles
    func fetchSubtitlePlaylist(playlistURL: String) {
        guard let url = URL(string: playlistURL) else { return }
        URLSession.shared.dataTask(with: url) {
            data,
            response,
            error in
            if let e = error {
                print(
                    "fetchSubtitlePlaylist => error: \(e.localizedDescription)"
                )
                return
            }
            guard let data = data,
                  let text = String(data: data, encoding: .utf8)
            else {
                print("fetchSubtitlePlaylist => invalid data")
                return
            }
            
            var vttFiles: [String] = []
            let lines = text.components(separatedBy: .newlines)
            var i = 0
            while i < lines.count {
                let line = lines[i]
                if line.hasPrefix("#EXTINF:") {
                    let nextLineIndex = i + 1
                    if nextLineIndex < lines.count {
                        let vttFile = lines[nextLineIndex].trimmingCharacters(
                            in: .whitespaces
                        )
                        if !vttFile.isEmpty {
                            let base = playlistURL.replacingOccurrences(
                                of: "/subtitles.m3u8",
                                with: "/"
                            )
                            let vttURL = base + vttFile
                            vttFiles.append(vttURL)
                        }
                        i += 1
                    }
                }
                i += 1
            }
            
            DispatchQueue.main.async {
                self.processVTTFiles(vttFiles)
            }
        }.resume()
    }
    
    private func processVTTFiles(_ vttFiles: [String]) {
        guard !vttFiles.isEmpty else { return }
        
        var pendingCount = vttFiles.count
        var newSegments: [SubtitleSegmentLink] = []
        
        for vttURL in vttFiles {
            determineSegmentTimes(vttURL: vttURL) { maybeLink in
                DispatchQueue.main.async {
                    pendingCount -= 1
                    if let link = maybeLink {
                        newSegments.append(link)
                    }
                    if pendingCount == 0 {
                        self.appendSegments(newSegments)
                    }
                }
            }
        }
    }
    
    private func appendSegments(_ newSegments: [SubtitleSegmentLink]) {
        let existingURLs = Set(
            self.subtitleViewModel.segments.map { $0.urlString
            })
        let trulyNew = newSegments.filter {
            !existingURLs.contains($0.urlString)
        }
        let sortedNew = trulyNew.sorted { $0.minStart < $1.minStart }
        self.subtitleViewModel.segments.append(contentsOf: sortedNew)
        
        if self.subtitleViewModel.currentSegment == nil,
           !self.subtitleViewModel.segments.isEmpty {
            self.subtitleViewModel.loadSegment(at: 0)
        }
    }
    
    
    // MARK: - Background Playback Support
    
    // Configure the player for background operation
    func configurePlayerForBackground() {
        guard let player = player else { return }
        
        // Enable background audio session
        backgroundManager.activateAudioSession()
        
        // Make the player item background-friendly
        player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Set up metadata for Now Playing info
        setupNowPlayingInfo()
        
        // Set up remote control event handling
        setupRemoteTransportControls()
    }
    
    // Clean up resources when playback ends
    func cleanupBackgroundPlayback() {
        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        // Remove command center targets
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        
        // Deactivate audio session
        backgroundManager.deactivateAudioSession()
    }
    
    
    
    // Set up Now Playing info for the lock screen
    private func setupNowPlayingInfo() {
        guard let player = player else { return }
        
        // Create Now Playing info dictionary
        var nowPlayingInfo = [String: Any]()
        
        // Add basic metadata
        nowPlayingInfo[MPMediaItemPropertyTitle] = thought.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = "myBrain"
        
        // Add cover artwork if available
        if let coverPath = thought.cover, !coverPath.isEmpty {
            let baseURL = "https://brain.sorenapp.ir"
            if let imageURL = URL(string: baseURL + coverPath),
               let imageData = try? Data(contentsOf: imageURL),
               let image = UIImage(data: imageData) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) {
                    _ in image
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }
        
        // Add playback duration and position
        if let currentItem = player.currentItem {
            let duration = currentItem.duration.seconds
            if !duration.isNaN && duration.isFinite {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player
            .currentTime().seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        
        // Set the info in the control center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfo() {
        guard let player = player else { return }
        
        // Get current Now Playing info
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            // If no info exists, set up from scratch
            setupNowPlayingInfo()
            return
        }
        
        // Update playback position
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player
            .currentTime().seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        
        // Update Now Playing center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Set up remote transport controls
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Handle play command
        commandCenter.playCommand.addTarget { [player] _ in
            guard let player = player else { return .commandFailed }
            
            player.play()
            // We need to update the main view's state through a different mechanism
            DispatchQueue.main.async {
                // We can't directly update self.isPlaying here
                // Instead, post a notification that the view can observe
                NotificationCenter.default.post(
                    name: NSNotification.Name("PlaybackStateChanged"),
                    object: nil,
                    userInfo: ["isPlaying": true]
                )
            }
            
            // We also need to update the now playing info through a different mechanism
            if let playingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                var updatedInfo = playingInfo
                updatedInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            }
            
            return .success
        }
        
        // Handle pause command
        commandCenter.pauseCommand.addTarget { [player] _ in
            guard let player = player else { return .commandFailed }
            
            player.pause()
            // We need to update the main view's state through a different mechanism
            DispatchQueue.main.async {
                // We can't directly update self.isPlaying here
                // Instead, post a notification that the view can observe
                NotificationCenter.default.post(
                    name: NSNotification.Name("PlaybackStateChanged"),
                    object: nil,
                    userInfo: ["isPlaying": false]
                )
            }
            
            // We also need to update the now playing info through a different mechanism
            if let playingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                var updatedInfo = playingInfo
                updatedInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
            }
            
            return .success
        }
    }
    
    
    
    // Set up handlers for audio interruptions and route changes
    private func setupInterruptionHandlers() {
        // Handle audio session interruptions (phone calls, etc.)
        NotificationCenter.default
            .publisher(for: Notification.Name("AudioInterruptionBegan"))
            .sink { [player] _ in
                // Audio interrupted (e.g., phone call)
                if self.isPlaying {
                    // Pause playback
                    player?.pause()
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("AudioInterruptionEnded"))
            .sink { [player] notification in
                // Check if we should automatically resume
                let shouldResume = notification.userInfo?["shouldResume"] as? Bool ?? false
                
                if shouldResume && !self.isPlaying {
                    // Automatically resume playback
                    player?.play()
                    self.isPlaying = true
                    self.updateNowPlayingInfo()
                }
            }
            .store(in: &cancellables)
    }
    
    // Handle audio route changes (headphones disconnected, etc.)
    private func setupRouteChangeHandlers() {
        NotificationCenter.default
            .publisher(for: Notification.Name("AudioRouteChanged"))
            .sink { [player] notification in
                if let reason = notification.userInfo?["reason"] as? String,
                   reason == "deviceDisconnected" {
                    // Headphones or other audio device was disconnected
                    // Pause playback to avoid startling the user with sudden audio from speakers
                    if self.isPlaying {
                        player?.pause()
                        self.isPlaying = false
                        self.updateNowPlayingInfo()
                    }
                }
            }
            .store(in: &cancellables)
    }
}


// MARK: - Helper for parsing time ranges in .vtt files
private func determineSegmentTimes(
    vttURL: String,
    completion: @escaping (
        SubtitleSegmentLink?
    ) -> Void
)
{
    guard let url = URL(string: vttURL) else {
        completion(nil)
        return
    }
    URLSession.shared.dataTask(with: url) {
        data,
        _,
        error in
        guard error == nil,
              let data = data,
              let content = String(data: data, encoding: .utf8)
        else {
            completion(nil)
            return
        }
        let lines = content.components(separatedBy: .newlines)
        
        var earliest = Double.greatestFiniteMagnitude
        var latest   = Double.leastNormalMagnitude
        
        let timeRegex = try! NSRegularExpression(
            pattern: #"(\d+):(\d+):(\d+\.\d+)\s-->\s(\d+):(\d+):(\d+\.\d+)"#,
            options: []
        )
        
        for line in lines {
            if let match = timeRegex.firstMatch(
                in: line,
                options: [],
                range: NSRange(location: 0, length: line.utf16.count)
            ) {
                let startTime = parseTime(
                    line: line,
                    match: match,
                    isStart: true
                )
                let endTime   = parseTime(
                    line: line,
                    match: match,
                    isStart: false
                )
                if let s = startTime,
                   let e = endTime {
                    earliest = min(earliest, s)
                    latest   = max(latest, e)
                }
            }
        }
        
        if earliest < Double.greatestFiniteMagnitude,
           latest   > Double.leastNormalMagnitude {
            let duration = latest - earliest
            let segmentLink = SubtitleSegmentLink(
                urlString: vttURL,
                duration: duration,
                minStart: earliest,
                maxEnd:   latest
            )
            completion(segmentLink)
        } else {
            completion(nil)
        }
    }
    .resume()
}

private func parseTime(line: String,
                       match: NSTextCheckingResult,
                       isStart: Bool) -> Double?
{
    let hourIndex   = isStart ? 1 : 4
    let minuteIndex = isStart ? 2 : 5
    let secondIndex = isStart ? 3 : 6
    
    func groupString(_ idx: Int) -> String {
        let range = match.range(at: idx)
        return (line as NSString).substring(with: range)
    }
    
    guard let hh = Double(groupString(hourIndex)),
          let mm = Double(groupString(minuteIndex)),
          let ss = Double(groupString(secondIndex))
    else {
        return nil
    }
    return hh * 3600.0 + mm * 60.0 + ss
}
