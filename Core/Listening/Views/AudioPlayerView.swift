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
            
            // Pre-load first segment if we get subtitles URL quickly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let subtitlesURL = viewModel.subtitlesURL {
                    print("Pre-loading subtitles on appear")
                    fetchSubtitlePlaylist(playlistURL: subtitlesURL)
                }
            }
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
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("InitialSubtitleLoad"))) { notification in
                if let data = notification.object as? [String: Any],
                   let subtitlesURL = data["url"] as? String {
                    print("Initial subtitle load triggered")
                    fetchSubtitlePlaylist(playlistURL: subtitlesURL)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSubtitles"))) { notification in
                if let data = notification.object as? [String: Any],
                   let subtitlesURL = data["url"] as? String {
                    print("Subtitle refresh triggered for new chapter")
                    fetchSubtitlePlaylist(playlistURL: subtitlesURL)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UpdateSubtitleTime"))) { notification in
                if let currentTime = notification.object as? Double {
                    subtitleViewModel.updateCurrentTime(currentTime)
                    
                    // Check if we need to switch to a different subtitle segment
                    subtitleViewModel.checkSegmentBoundary { newIndex in
                        print("Switching to subtitle segment \(newIndex) at time \(currentTime)")
                        subtitleViewModel.loadSegment(at: newIndex)
                    }
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
        print("Fetching subtitle playlist: \(playlistURL)")
        
        guard let url = URL(string: playlistURL) else {
            print("Invalid subtitle playlist URL: \(playlistURL)")
            return
        }
        
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
            
            print("Received subtitle playlist with \(text.components(separatedBy: .newlines).count) lines")
            
            // Parse M3U8 playlist more efficiently
            let vttFiles = parseM3U8Playlist(text, baseURL: playlistURL)
            
            DispatchQueue.main.async {
                print("Processing \(vttFiles.count) VTT files")
                self.processVTTFiles(vttFiles)
            }
        }.resume()
    }
    
    private func parseM3U8Playlist(_ content: String, baseURL: String) -> [String] {
        var vttFiles: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        let base = baseURL.replacingOccurrences(of: "/subtitles.m3u8", with: "/")
        
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            // Look for .vtt files directly
            if line.hasSuffix(".vtt") && !line.hasPrefix("#") {
                let vttURL = base + line
                vttFiles.append(vttURL)
                print("Found VTT file: \(vttURL)")
            }
        }
        
        return vttFiles
    }
    
    private func processVTTFiles(_ vttFiles: [String]) {
        guard !vttFiles.isEmpty else {
            print("No VTT files to process")
            return
        }
        
        // Process files sequentially to avoid overwhelming the system
        processVTTFile(at: 0, from: vttFiles, accumulated: [])
    }
    
    private func processVTTFile(at index: Int, from vttFiles: [String], accumulated: [SubtitleSegmentLink]) {
        guard index < vttFiles.count else {
            // All files processed, update segments
            self.appendSegments(accumulated)
            return
        }
        
        let vttURL = vttFiles[index]
        print("Processing VTT file \(index + 1)/\(vttFiles.count): \(vttURL)")
        
        determineSegmentTimes(vttURL: vttURL) { maybeLink in
            DispatchQueue.main.async {
                var newAccumulated = accumulated
                if let link = maybeLink {
                    newAccumulated.append(link)
                }
                
                // Process next file
                self.processVTTFile(at: index + 1, from: vttFiles, accumulated: newAccumulated)
            }
        }
    }
    
    private func appendSegments(_ newSegments: [SubtitleSegmentLink]) {
        print("Appending \(newSegments.count) subtitle segments")
        
        let existingURLs = Set(subtitleViewModel.segments.map { $0.urlString })
        let trulyNew = newSegments.filter { !existingURLs.contains($0.urlString) }
        let sortedNew = trulyNew.sorted { $0.minStart < $1.minStart }
        
        print("Adding \(sortedNew.count) new segments (filtered \(newSegments.count - sortedNew.count) duplicates)")
        
        subtitleViewModel.segments.append(contentsOf: sortedNew)
        
        // Load the first segment immediately if no current segment
        if subtitleViewModel.currentSegment == nil, !subtitleViewModel.segments.isEmpty {
            print("Loading first subtitle segment")
            subtitleViewModel.loadSegment(at: 0)
        }
        
        print("Total subtitle segments: \(subtitleViewModel.segments.count)")
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
