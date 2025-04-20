// StreamThoughtView.swift

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
    
    @State private var lastCheckTime: Double = 0.0
    @State private var startTime: Date?
    @State private var isPlaying = false
    
    /// Time in seconds after which we request the next chapter.
    @State private var nextChapterTime: Double? = nil
    
    /// Buffer factor so we can request the next chapter slightly before the current one ends.
    private let buffer: Double = 0.60
    
    // Subtitles
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    @State private var subsUrlStr: String?
    
    var body: some View {
        // ------------------------------------------
        // Wrap our main stream UI inside ThoughtNavigationView
        // ------------------------------------------
        ThoughtNavigationView(
            thought: thought,
            socketViewModel: socketViewModel
        ) {
            // The MAIN content for streaming, shown once user chooses “Resume” or if brand new
            ZStack {
                Color.clear.ignoresSafeArea()
                
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
                            socketViewModel: socketViewModel
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
        // ------------------------------------------
        // Provide closures for resume and reset
        // ------------------------------------------
        .onResume {
            // Called when user picks “Resume” in the overlay (if in_progress)
            // or after “not_started” with no prompt needed.
            fetchStreamingLinks()
        }
        .onResetFinished {
            // Called when user picks “Restart From Beginning” and server reset is successful
            // We can clear out relevant local state, then fetch fresh streaming links:
            durations_so_far = 0
            nextChapterTime = nil
            fetchStreamingLinks()
        }
        // Clean up player on disappear
        .onDisappear {
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
                    player?.pause()
                } else {
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
    
    // MARK: - Fetch Streaming
    func fetchStreamingLinks() {
        isFetchingLinks = true
        // Send the request for streaming links
        socketViewModel.sendMessage(action: "streaming_links", data: ["thought_id": thought.id])
        
        // Listen for streaming_links response
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "streaming_links" }
            .first()
            .sink { message in
                DispatchQueue.main.async {
                    self.handleStreamingLinksResponse(message: message)
                    // Clear the incoming message to avoid repeated triggers
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
        
        // Listen for the initial chapter_response
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                DispatchQueue.main.async {
                    self.handleNextChapterResponse(message: message)
                    self.socketViewModel.incomingMessage = nil
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    private func handleStreamingLinksResponse(message: [String: Any]) {
        isFetchingLinks = false
        
        guard let status = message["status"] as? String,
              status == "success",
              let data = message["data"] as? [String: Any],
              let masterPlaylistPath = data["master_playlist"] as? String
        else {
            let errorMessage = message["message"] as? String ?? "Failed to get the streaming URLs"
            playerError = NSError(domain: "StreamingError", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
            return
        }
        
        let baseURL = "https://\(socketViewModel.baseUrl)"
        guard let url = URL(string: baseURL + masterPlaylistPath) else {
            let errorMessage = "Invalid URL: \(baseURL + masterPlaylistPath)"
            playerError = NSError(domain: "StreamingError", code: -3,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
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
    
    // MARK: - Setup Player
    func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        isPlaying = true
        player?.play()
        startTime = Date()
        
        if playerItemObservation == nil {
            playerItemObservation = player?.publisher(for: \.currentItem?.status)
                .compactMap { $0 }
                .sink { status in
                    if status == .readyToPlay {
                        self.startPlaybackProgressObservation()
                    }
                }
        }
    }
    
    func startPlaybackProgressObservation() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
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
        }
    }
    
    // MARK: - Check Progress & Request Next Chapter
    func checkPlaybackProgress(currentTime: Double) {
        guard let nextChapterTime = nextChapterTime, !nextChapterRequested else {
            return
        }
        if currentTime >= nextChapterTime {
            nextChapterRequested = true
            requestNextChapter()
        }
    }
    
    func requestNextChapter() {
        socketViewModel.incomingMessage = nil
        let data: [String: Any] = ["thought_id": thought.id, "generate_audio": true]
        socketViewModel.sendMessage(action: "next_chapter", data: data)
        
        socketViewModel.$incomingMessage
            .compactMap { $0 }
            .filter { $0["type"] as? String == "chapter_response" }
            .first()
            .sink { message in
                self.handleNextChapterResponse(message: message)
                self.socketViewModel.incomingMessage = nil
            }
            .store(in: &socketViewModel.cancellables)
    }
    
    // MARK: - Handle Next Chapter
    func handleNextChapterResponse(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any] else { return }
        
        let chapterNumber = data["chapter_number"] as? Int ?? 0
        let audioDuration = data["audio_duration"] as? Double ?? 0.0
        let generationTime = data["generation_time"] as? Double ?? 0.0
        
        currentChapterNumber = chapterNumber

        let playableDuration = audioDuration - generationTime
        nextChapterTime = durations_so_far + (playableDuration * (1 - buffer))
        
        nextChapterRequested = false
        durations_so_far += audioDuration
        
        // Re‐fetch updated subtitles
        if let subsUrlStr = subsUrlStr {
            fetchSubtitlePlaylist(playlistURL: subsUrlStr)
        }
    }
    
    // MARK: - Subtitles
    func fetchSubtitlePlaylist(playlistURL: String) {
        guard let url = URL(string: playlistURL) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let e = error {
                print("fetchSubtitlePlaylist => error: \(e.localizedDescription)")
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
                        let vttFile = lines[nextLineIndex].trimmingCharacters(in: .whitespaces)
                        if !vttFile.isEmpty {
                            let base = playlistURL.replacingOccurrences(of: "/subtitles.m3u8", with: "/")
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
        let existingURLs = Set(self.subtitleViewModel.segments.map { $0.urlString })
        let trulyNew = newSegments.filter { !existingURLs.contains($0.urlString) }
        let sortedNew = trulyNew.sorted { $0.minStart < $1.minStart }
        self.subtitleViewModel.segments.append(contentsOf: sortedNew)
        
        if self.subtitleViewModel.currentSegment == nil,
           !self.subtitleViewModel.segments.isEmpty {
            self.subtitleViewModel.loadSegment(at: 0)
        }
    }
}

// MARK: - Helper for parsing time ranges in .vtt files
private func determineSegmentTimes(vttURL: String,
                                   completion: @escaping (SubtitleSegmentLink?) -> Void)
{
    guard let url = URL(string: vttURL) else {
        completion(nil)
        return
    }
    URLSession.shared.dataTask(with: url) { data, _, error in
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
                let startTime = parseTime(line: line, match: match, isStart: true)
                let endTime   = parseTime(line: line, match: match, isStart: false)
                if let s = startTime, let e = endTime {
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
