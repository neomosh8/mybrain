import SwiftUI
import AVFoundation
import Combine

struct AudioPlayerView: View {
    let thought: Thought
    
    @StateObject private var viewModel = AudioStreamingViewModel()
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    @EnvironmentObject var backgroundManager: BackgroundManager
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            if viewModel.hasCompletedPlayback {
                ChapterCompletionView(thoughtId: thought.id)
            } else {
                VStack(spacing: 20) {
                    if viewModel.isFetchingLinks {
                        fetchingLinksView
                    } else if viewModel.player != nil {
                        audioContentView
                    } else if let error = viewModel.playerError {
                        errorView(error)
                    } else {
                        readyView
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.startListening(for: thought)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Subviews
    
    private var fetchingLinksView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Fetching Streaming Links...")
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
    
    private var audioContentView: some View {
        VStack(spacing: 20) {
            // Thought info
            thoughtInfoView
            
            // Audio controls
            AudioControlsView(viewModel: viewModel)
            
            // Subtitles
            SubtitleView(
                viewModel: subtitleViewModel,
                thoughtId: thought.id,
                chapterNumber: $viewModel.currentChapterNumber
            )
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSubtitles"))) { notification in
                if let subtitlesURL = notification.object as? String {
                    fetchSubtitlePlaylist(playlistURL: subtitlesURL)
                }
            }
            
            Spacer()
        }
    }
    
    private var thoughtInfoView: some View {
        VStack(spacing: 8) {
            Text(thought.name)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            if viewModel.currentChapterNumber > 0 {
                Text("Chapter \(viewModel.currentChapterNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Player Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.startListening(for: thought)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var readyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Ready to Stream")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(thought.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Subtitle Management
    
    private func fetchSubtitlePlaylist(playlistURL: String) {
        guard let url = URL(string: playlistURL) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("fetchSubtitlePlaylist => error: \(error.localizedDescription)")
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
        let existingURLs = Set(subtitleViewModel.segments.map { $0.urlString })
        let trulyNew = newSegments.filter { !existingURLs.contains($0.urlString) }
        let sortedNew = trulyNew.sorted { $0.minStart < $1.minStart }
        subtitleViewModel.segments.append(contentsOf: sortedNew)
        
        if subtitleViewModel.currentSegment == nil, !subtitleViewModel.segments.isEmpty {
            subtitleViewModel.loadSegment(at: 0)
        }
    }
    
    private func determineSegmentTimes(vttURL: String, completion: @escaping (SubtitleSegmentLink?) -> Void) {
        guard let url = URL(string: vttURL) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("determineSegmentTimes error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            let timeRegex = try! NSRegularExpression(
                pattern: #"(\d+):(\d+):(\d+\.\d+)\s-->\s(\d+):(\d+):(\d+\.\d+)"#,
                options: []
            )
            
            let lines = content.components(separatedBy: .newlines)
            var minStart: Double = Double.greatestFiniteMagnitude
            var maxEnd: Double = 0
            
            for line in lines {
                if let match = timeRegex.firstMatch(
                    in: line,
                    options: [],
                    range: NSRange(location: 0, length: line.utf16.count)
                ) {
                    if let startTime = self.parseTime(from: line, match: match, isStart: true),
                       let endTime = self.parseTime(from: line, match: match, isStart: false) {
                        minStart = min(minStart, startTime)
                        maxEnd = max(maxEnd, endTime)
                    }
                }
            }
            
            if minStart != Double.greatestFiniteMagnitude {
                let link = SubtitleSegmentLink(
                    urlString: vttURL,
                    minStart: minStart,
                    maxEnd: maxEnd
                )
                completion(link)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func parseTime(from line: String, match: NSTextCheckingResult, isStart: Bool) -> Double? {
        let hourIndex = isStart ? 1 : 4
        let minuteIndex = isStart ? 2 : 5
        let secondIndex = isStart ? 3 : 6
        
        guard let hourRange = Range(match.range(at: hourIndex), in: line),
              let minuteRange = Range(match.range(at: minuteIndex), in: line),
              let secondRange = Range(match.range(at: secondIndex), in: line) else { return nil }
        
        let hourStr = String(line[hourRange])
        let minuteStr = String(line[minuteRange])
        let secondStr = String(line[secondRange])
        
        guard let hour = Int(hourStr),
              let minute = Int(minuteStr),
              let second = Double(secondStr) else { return nil }
        
        return Double(hour * 3600) + Double(minute * 60) + second
    }
}
