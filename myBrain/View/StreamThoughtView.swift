import SwiftUI
import AVKit
import Combine

struct StreamThoughtView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel
    
    @State private var player: AVPlayer?
    @State private var playerError: Error?
    @State private var isFetchingLinks = false
    @State private var masterPlaylistURL: URL?
    
    @State private var nextChapterRequested = false
    @State private var playerItemObservation: AnyCancellable?
    @State private var playbackProgressObserver: Any?
    @State private var currentChapterNumber: Int = 1
    
    @State private var showRestartOptions = false
    @State private var thoughtStatus: ThoughtStatus?
    @State private var showResetSuccess = false
    @State private var resetCompleted = false
    
    @State private var lastCheckTime: Double = 0.0
    @State private var startTime: Date?
    @State private var isPlaying = false
    
    /// Time in seconds after which we request the next chapter.
    @State private var nextChapterTime: Double? = nil

    /// Accumulated time to keep track of total duration played.
    @State private var totalElapsedTime: Double = 0.0
    
    /// Buffer factor so we can request the next chapter slightly before the current one ends.
    private let buffer: Double = 0.40
    
    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            VStack {
                if isFetchingLinks {
                    ProgressView("Fetching Streaming Links...")
                } else if let player = player {
                    if thought.content_type == "audio" {
                        audioPlayerControls
                    } else {
                        VideoPlayer(player: player)
                            .frame(minHeight: 200)
                    }
                } else if let error = playerError {
                    Text("Player Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                } else {
                    Text("Ready to Stream \(thought.name)")
                        .foregroundColor(.black)
                }
            }
            .padding()
            
            if showRestartOptions {
                restartOptionsAlert
            }
        }
        .alert(isPresented: $showResetSuccess) {
            Alert(
                title: Text("Success"),
                message: Text("Reading progress reset successfully"),
                dismissButton: .default(Text("Ok"))
            )
        }
        .onAppear {
            print("onAppear => fetchThoughtStatus()")
            fetchThoughtStatus()
        }
        .onDisappear {
            print("onDisappear => cleaning up players/observers")
            player?.pause()
            player = nil
            masterPlaylistURL = nil
            playerItemObservation?.cancel()
            if let observer = playbackProgressObserver {
                player?.removeTimeObserver(observer)
            }
            playbackProgressObserver = nil
        }
    }
    
    // MARK: - Audio Player Controls
    private var audioPlayerControls: some View {
        HStack {
            Button(action: {
                if isPlaying {
                    print("audioPlayerControls => pause tapped")
                    player?.pause()
                } else {
                    print("audioPlayerControls => play tapped")
                    player?.play()
                }
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - 1. Thought Status
    func fetchThoughtStatus() {
        print("fetchThoughtStatus => sending 'thought_status' for thought.id = \(thought.id)")
        socketViewModel.sendMessage(action: "thought_status", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "thought_chapters" }
            .first()
            .sink { message in
                print("fetchThoughtStatus => got thought_chapters => handleThoughtStatusResponse")
                DispatchQueue.main.async {
                    self.handleThoughtStatusResponse(message: message)
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    func handleThoughtStatusResponse(message: [String: Any]) {
        print("handleThoughtStatusResponse => \(message)")
        guard let status = message["status"] as? String,
              status == "success",
              let data = message["data"] as? [String: Any],
              let thoughtId = data["thought_id"] as? Int,
              let thoughtName = data["thought_name"] as? String,
              let statusType = data["status"] as? String,
              let progressData = data["progress"] as? [String: Any],
              let chaptersData = data["chapters"] as? [[String: Any]]
        else {
            print("handleThoughtStatusResponse => missing data, returning")
            return
        }
        
        let progress = ProgressData(
            total: progressData["total"] as? Int ?? 0,
            completed: progressData["completed"] as? Int ?? 0,
            remaining: progressData["remaining"] as? Int ?? 0
        )
        
        var chapters: [ChapterDataModel] = []
        for chapterData in chaptersData {
            let chapter = ChapterDataModel(
                chapter_number: chapterData["chapter_number"] as? Int ?? 0,
                title: chapterData["title"] as? String ?? "",
                content: chapterData["content"] as? String ?? "",
                status: chapterData["status"] as? String ?? ""
            )
            chapters.append(chapter)
        }
        
        let statusModel = ThoughtStatus(
            thought_id: thoughtId,
            thought_name: thoughtName,
            status: statusType,
            progress: progress,
            chapters: chapters
        )
        self.thoughtStatus = statusModel
        
        print("handleThoughtStatusResponse => statusType = \(statusType)")
        if statusType == "in_progress" {
            print("handleThoughtStatusResponse => showRestartOptions = true (in_progress)")
            showRestartOptions = true
        } else if statusType == "finished" {
            print("handleThoughtStatusResponse => showRestartOptions = true (finished)")
            showRestartOptions = true
        } else {
            print("handleThoughtStatusResponse => calling fetchStreamingLinks()")
            fetchStreamingLinks()
        }
    }
    
    // MARK: - 2. Restart / Reset
    var restartOptionsAlert: some View {
        VStack {
            if thoughtStatus?.status == "in_progress" {
                Text("It seems you are in the middle of the stream for \(thought.name).")
                    .font(.headline)
                    .padding()
                
                HStack {
                    Button("Restart From Beginning") {
                        print("restartOptionsAlert => user tapped 'Restart From Beginning'")
                        resetReading()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Resume") {
                        print("restartOptionsAlert => user tapped 'Resume'")
                        showRestartOptions = false
                        fetchStreamingLinks()
                    }
                    .buttonStyle(.bordered)
                }
                
            } else {
                Text("It seems you have finished the stream for \(thought.name).")
                    .font(.headline)
                    .padding()
                
                Button("Restart From Beginning") {
                    print("restartOptionsAlert => user tapped 'Restart From Beginning' (finished)")
                    resetReading()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
    
    func resetReading() {
        print("resetReading => sending 'reset_reading' for thought.id = \(thought.id)")
        resetCompleted = false
        socketViewModel.sendMessage(action: "reset_reading", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "reset_response" }
            .first()
            .sink { message in
                print("resetReading => got 'reset_response' => handleResetResponse")
                DispatchQueue.main.async {
                    self.handleResetResponse(message: message)
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    func handleResetResponse(message: [String: Any]) {
        print("handleResetResponse => \(message)")
        guard let status = message["status"] as? String,
              status == "success" else {
            print("handleResetResponse => reset reading was unsuccessful")
            return
        }
        
        print("handleResetResponse => success => showResetSuccess, fetchStreamingLinks()")
        showResetSuccess = true
        showRestartOptions = false
        resetCompleted = true
        fetchStreamingLinks()
        totalElapsedTime = 0.0 // Reset total elapsed time when restarting the stream
        nextChapterTime = nil // Reset next chapter time
    }
    
    // MARK: - 3. Fetch Streaming
    func fetchStreamingLinks() {
        isFetchingLinks = true
        print("fetchStreamingLinks => sending 'streaming_links' for thought.id = \(thought.id)")
        socketViewModel.sendMessage(action: "streaming_links", data: ["thought_id": thought.id])
        
        // 1) streaming_links response
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "streaming_links" }
            .first()
            .sink { message in
                print("fetchStreamingLinks => got streaming_links => handleStreamingLinksResponse")
                DispatchQueue.main.async {
                    self.handleStreamingLinksResponse(message: message)
                }
            }
            .store(in: &socketViewModel.cancellables)
        
        // 2) initial chapter_response
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                print("fetchStreamingLinks => got initial chapter_response => handleNextChapterResponse")
                DispatchQueue.main.async {
                    self.handleNextChapterResponse(message: message)
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    func handleStreamingLinksResponse(message: [String: Any]) {
        print("handleStreamingLinksResponse => \(message)")
        isFetchingLinks = false
        
        guard let status = message["status"] as? String,
              status == "success" else {
            let errorMessage = message["message"] as? String ?? "Failed to get the streaming URLs"
            print("handleStreamingLinksResponse => not success => \(errorMessage)")
            playerError = NSError(domain: "StreamingError", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return
        }
        guard let data = message["data"] as? [String: Any],
              let masterPlaylistPath = data["master_playlist"] as? String else {
            let errorMessage = "Missing master_playlist in data"
            print("handleStreamingLinksResponse => \(errorMessage)")
            playerError = NSError(domain: "StreamingError", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return
        }
        
        let baseURL = "https://\(socketViewModel.baseUrl)"
        guard let url = URL(string: baseURL + masterPlaylistPath) else {
            let errorMessage = "Invalid URL: \(baseURL + masterPlaylistPath)"
            print("handleStreamingLinksResponse => \(errorMessage)")
            playerError = NSError(domain: "StreamingError", code: -3,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return
        }
        
        self.masterPlaylistURL = url
        
        if let subsPath = data["subtitles_playlist"] as? String,
           !subsPath.isEmpty {
            let subUrl = baseURL + subsPath
            print("handleStreamingLinksResponse => subtitle url = \(subUrl)")
        }
        
        print("handleStreamingLinksResponse => setupPlayer(url: \(url))")
        setupPlayer(url: url)
    }
    
    // MARK: - 4. Setup Player
    func setupPlayer(url: URL) {
        print("setupPlayer => creating AVPlayerItem => \(url)")
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        isPlaying = true
        player?.play()
        startTime = Date()
        
        if playerItemObservation == nil {
            playerItemObservation = player?.publisher(for: \.currentItem?.status)
                .compactMap { $0 }
                .sink { status in
                    print("playerItemObservation => AVPlayerItem status changed: \(status.rawValue)")
                    if status == .readyToPlay {
                        print("playerItemObservation => status == .readyToPlay => startPlaybackProgressObservation()")
                        self.startPlaybackProgressObservation()
                    } else {
                        print("playerItemObservation => status != .readyToPlay => \(status.rawValue)")
                    }
                }
        }
    }
    
    func startPlaybackProgressObservation() {
        guard let player = player else {
            print("startPlaybackProgressObservation => no player!")
            return
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        print("startPlaybackProgressObservation => addPeriodicTimeObserver(0.5s)")
        playbackProgressObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            print("time observer => currentTime: \(time.seconds)")
            self.checkPlaybackProgress(currentTime: time.seconds)
        }
    }
    
    // MARK: - 5. Check Progress & Request Next Chapter
    func checkPlaybackProgress(currentTime: Double) {
        guard let _ = player else {
            print("checkPlaybackProgress => guard #1: player is nil, returning")
            return
        }
        
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            print("checkPlaybackProgress => total elapsed: \(elapsed)")
        }
        
        guard let nextChapterTime = nextChapterTime else {
            print("checkPlaybackProgress => nextChapterTime is nil, so no next chapter request yet.")
            return
        }
        
        if currentTime >= nextChapterTime && !nextChapterRequested {
            print("checkPlaybackProgress => currentTime >= nextChapterTime => requestNextChapter()")
            nextChapterRequested = true
            requestNextChapter()
        }
    }
    
    func requestNextChapter() {
        print("requestNextChapter => sending 'next_chapter'")
        let data: [String: Any] = ["thought_id": thought.id, "generate_audio": true]
        socketViewModel.sendMessage(action: "next_chapter", data: data)
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                print("requestNextChapter => got next chapter_response => handleNextChapterResponse")
                self.handleNextChapterResponse(message: message)
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    // MARK: - 6. Handle Next Chapter – Treat Each Chapter as a Fresh 0–N Timeline
    func handleNextChapterResponse(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any] else { return }
        
        let chapterNumber = data["chapter_number"] as? Int ?? 0
        let audioDuration = data["audio_duration"] as? Double ?? 0.0
        let generationTime = data["generation_time"] as? Double ?? 0.0
        print("handleNextChapterResponse => chapterNumber=\(chapterNumber), audioDuration=\(audioDuration), generationTime=\(generationTime)")
        
        // calculate the actual play duration of this segment
        let playableDuration = audioDuration - generationTime
        let timeToRequestNextChapter = playableDuration * (1 - buffer) // e.g. 80% of the playable segment
    
        if nextChapterTime == nil {
            // This is the first chapter. set it to the proper buffered time of it.
            nextChapterTime = timeToRequestNextChapter
            print("handleNextChapterResponse => first chapter => nextChapterTime = \(String(describing: nextChapterTime))")
        } else {
            // if a nextChapterTime exists, we add the last playable duration so it is cummulative
            nextChapterTime! += timeToRequestNextChapter // Add to total time
           print("handleNextChapterResponse => next chapter, nextChapterTime = \(String(describing: nextChapterTime))")
         }
        
        nextChapterRequested = false // reset this flag for next chapter

        // DO NOT call refetchPlaylistAndPlay. We let the single AVPlayer keep going.
    }

    
    /// Force re-init the same .m3u8, always seeking to .zero
    func refetchPlaylistAndPlay() {
        guard let masterURL = masterPlaylistURL else {
            print("refetchPlaylistAndPlay => no masterPlaylistURL, cannot re-init")
            return
        }
        
        print("refetchPlaylistAndPlay => pausing old player, then reinit from 0s")
        player?.pause()
        
        // remove old observers
        playerItemObservation?.cancel()
        playerItemObservation = nil
        if let observer = playbackProgressObserver {
            player?.removeTimeObserver(observer)
        }
        playbackProgressObserver = nil
        
        // create the new AVPlayerItem
        let newItem = AVPlayerItem(url: masterURL)
        player?.replaceCurrentItem(with: newItem)
        
        // re-observe
        playerItemObservation = player?.publisher(for: \.currentItem?.status)
            .compactMap { $0 }
            .sink { status in
                print("refetchPlaylistAndPlay => new item status: \(status.rawValue)")
                if status == .readyToPlay {
                    print("refetchPlaylistAndPlay => new item ready => seeking to 0s")
                    self.player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        print("refetchPlaylistAndPlay => successfully sought to 0s")
                        self.player?.play()
                        self.isPlaying = true
                        self.startPlaybackProgressObservation()
                    }
                }
            }
    }
    
    // MARK: - Models
    struct ThoughtStatus {
        let thought_id: Int
        let thought_name: String
        let status: String
        let progress: ProgressData
        let chapters: [ChapterDataModel]
    }
    
    struct ProgressData {
        let total: Int
        let completed: Int
        let remaining: Int
    }
    
    struct ChapterDataModel {
        let chapter_number: Int
        let title: String
        let content: String
        let status: String
    }
    
    // For example, if you need subtitles
    struct SubtitleSegment: Equatable {
        let startTime: Double
        let endTime: Double
        var text: String
    }
}
