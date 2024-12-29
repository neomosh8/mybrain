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
    @State private var durations_so_far: Double = 0.0
    @State private var showRestartOptions = false
    @State private var thoughtStatus: ThoughtStatus?
    @State private var showResetSuccess = false
    @State private var resetCompleted = false
    
    @State private var lastCheckTime: Double = 0.0
    @State private var startTime: Date?
    @State private var isPlaying = false
    
    /// Time in seconds after which we request the next chapter.
    @State private var nextChapterTime: Double? = nil
    
    /// Buffer factor so we can request the next chapter slightly before the current one ends.
    private let buffer: Double = 0.60
    
    // MARK: - NEW CODE: Subtitles
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    // MARK: End of NEW CODE
    @State private var subsUrlStr: String?
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            VStack {
                if isFetchingLinks {
                    ProgressView("Fetching Streaming Links...")
                } else if let player = player {
                    // Audio controls only
                    audioPlayerControls
                    // MARK: - NEW CODE: Show Subtitles
                    SubtitleView(viewModel: subtitleViewModel)
                    // MARK: End of NEW CODE
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
                    .foregroundColor(.blue)
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
                    // Optional: clear it out
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    func handleThoughtStatusResponse(message: [String: Any]) {
        print("handleThoughtStatusResponse => \(message)")
        
        // Expecting:
        // "data" : "success"
        // "message": {
        //   "thought_id": ...
        //   "thought_name": ...
        //   "status": ...
        //   "progress": {...}
        //   "chapters": [...]
        // }
        
        guard let dataValue = message["data"] as? String,
              dataValue == "success",
              let messageDict = message["message"] as? [String: Any],
              let thoughtId = messageDict["thought_id"] as? Int,
              let thoughtName = messageDict["thought_name"] as? String,
              let statusType = messageDict["status"] as? String,
              let progressData = messageDict["progress"] as? [String: Any],
              let chaptersData = messageDict["chapters"] as? [[String: Any]]
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
                    // Optional: clear it out
                    self.socketViewModel.incomingMessage = nil
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
        nextChapterTime = nil
    }
    
    // MARK: - 3. Fetch Streaming
    func fetchStreamingLinks() {
        isFetchingLinks = true
        print("fetchStreamingLinks => sending 'streaming_links' for thought.id = \(thought.id)")
        socketViewModel.sendMessage(action: "streaming_links", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "streaming_links" }
            .first()
            .sink { message in
                print("fetchStreamingLinks => got streaming_links => handleStreamingLinksResponse")
                DispatchQueue.main.async {
                    self.handleStreamingLinksResponse(message: message)
                    // Optional: clear it out
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
        
        // IMPORTANT: first chapter info
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                print("fetchStreamingLinks => got initial chapter_response => handleNextChapterResponse")
                DispatchQueue.main.async {
                    self.handleNextChapterResponse(message: message)
                    // Optional: clear it out
                    self.socketViewModel.incomingMessage = nil
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
        
        // MARK: - NEW CODE: Handle Subtitles
        if let subsPath = data["subtitles_playlist"] as? String, !subsPath.isEmpty {
            let subsUrlStr = baseURL + subsPath
            print("handleStreamingLinksResponse => subtitles_playlist url = \(subsUrlStr)")
            // Fetch the .m3u8 for subtitles, parse it, and store in subtitleViewModel
            fetchSubtitlePlaylist(playlistURL: subsUrlStr)
            self.subsUrlStr = subsUrlStr
        }
        // MARK: End of NEW CODE
        
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
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        print("startPlaybackProgressObservation => addPeriodicTimeObserver(0.1s)")
        playbackProgressObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let currentTime = time.seconds
            self.checkPlaybackProgress(currentTime: currentTime)
            
            // MARK: - NEW CODE: Update subtitle time
            self.subtitleViewModel.updateCurrentTime(currentTime)
            // If we detect that the current segment ended, load next
            self.subtitleViewModel.checkSegmentBoundary { nextSegmentIndex in
                self.subtitleViewModel.loadSegment(at: nextSegmentIndex)
            }
            // MARK: End of NEW CODE
        }
    }
    
    // MARK: - 5. Check Progress & Request Next Chapter
    func checkPlaybackProgress(currentTime: Double) {
        print(currentTime)
        guard let _ = player else {
            print("checkPlaybackProgress => guard #1: player is nil, returning")
            return
        }
        
        guard let nextChapterTime = nextChapterTime else {
            // No next chapter scheduled yet
            return
        }
        
        if currentTime >= nextChapterTime && !nextChapterRequested {
            print("checkPlaybackProgress => currentTime >= nextChapterTime => requestNextChapter()")
            nextChapterRequested = true
            requestNextChapter()
        }
    }
    
    func requestNextChapter() {
        self.socketViewModel.incomingMessage = nil
        print("requestNextChapter => sending 'next_chapter'")
        let data: [String: Any] = ["thought_id": thought.id, "generate_audio": true]
        socketViewModel.sendMessage(action: "next_chapter", data: data)
        print("GOOOH", socketViewModel.incomingMessage ?? "No message")
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                print("requestNextChapter => got next chapter_response => handleNextChapterResponse")
                self.handleNextChapterResponse(message: message)
                // Optional: clear it out
                self.socketViewModel.incomingMessage = nil
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    // MARK: - 6. Handle Next Chapter
    func handleNextChapterResponse(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any] else { return }
        
        let chapterNumber = data["chapter_number"] as? Int ?? 0
        let audioDuration = data["audio_duration"] as? Double ?? 0.0
        let generationTime = data["generation_time"] as? Double ?? 0.0
        print("handleNextChapterResponse => chapterNumber=\(chapterNumber), audioDuration=\(audioDuration), generationTime=\(generationTime)")
        // "playableDuration" is the approximate length (in seconds) of the new chapter's audio.
        let playableDuration = audioDuration - generationTime
        
        // ---- CHANGED HERE (accumulate from previous chapters) ----
        self.nextChapterTime = durations_so_far + playableDuration * (1 - buffer)
        // ----------------------------------------------------------
        
        print("handleNextChapterResponse => new nextChapterTime = \(String(describing: nextChapterTime))")
        
        nextChapterRequested = false
        self.socketViewModel.incomingMessage = nil
        
        // We let the single AVPlayer keep going, no need to refetch here
        durations_so_far += audioDuration
        if let subsUrlStr = subsUrlStr { fetchSubtitlePlaylist(playlistURL: subsUrlStr)}
        
    }
    
    // MARK: - NEW CODE: Fetch the Subtitles Playlist (.m3u8) and parse it
    func fetchSubtitlePlaylist(playlistURL: String) {
        guard let url = URL(string: playlistURL) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let e = error {
                print("fetchSubtitlePlaylist => error: \(e.localizedDescription)")
                return
            }
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                print("fetchSubtitlePlaylist => invalid data")
                return
            }
            // parse lines for #EXTINF and the subsequent .vtt
            var segments: [SubtitleSegmentLink] = []
            let lines = text.components(separatedBy: .newlines)
            var i = 0
            while i < lines.count {
                let line = lines[i]
                if line.hasPrefix("#EXTINF:") {
                    // parse duration
                    let durationString = line
                        .replacingOccurrences(of: "#EXTINF:", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    
                    if let duration = Double(durationString) {
                        let nextLineIndex = i + 1
                        if nextLineIndex < lines.count {
                            let vttFile = lines[nextLineIndex].trimmingCharacters(in: .whitespaces)
                            if !vttFile.isEmpty {
                                // build absolute url from relative path
                                let base = playlistURL.replacingOccurrences(of: "/subtitles.m3u8", with: "/")
                                let vttURL = base + vttFile
                                let segment = SubtitleSegmentLink(urlString: vttURL,
                                                                  duration: duration)
                                segments.append(segment)
                            }
                            i += 1
                        }
                    }
                }
                i += 1
            }
            
            DispatchQueue.main.async {
                self.subtitleViewModel.segments = segments
                // load the first segment
                self.subtitleViewModel.loadSegment(at: 0)
            }
        }.resume()
    }
    // MARK: End of NEW CODE
}
