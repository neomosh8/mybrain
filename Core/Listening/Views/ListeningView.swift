import SwiftUI
import AVFoundation
import Combine

struct ListeningView: View {
    let thought: Thought
    
    // ViewModels
    @StateObject private var audioViewModel = AudioStreamingViewModel()
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    @StateObject private var statusViewModel = ListeningStatusViewModel()
    
    // UI State
    @State private var showStatusOverlay = false
    @State private var currentTime: Double = 0
    @State private var currentWordIndex: Int = 0
    @State private var previousWordIndex: Int = -1
    @State private var timeUpdateTimer: Timer?
    
    // Dependencies
    @EnvironmentObject var backgroundManager: BackgroundManager
    private let feedbackService: any FeedbackServiceProtocol = FeedbackService.shared
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            
            // Main Content
            mainContentView
                .blur(radius: showStatusOverlay ? 3 : 0)
            
            // Status Overlay
            if showStatusOverlay {
                statusOverlayView
            }
        }
        .onAppear {
            checkThoughtStatus()
        }
        .onDisappear {
            audioViewModel.cleanup()
            timeUpdateTimer?.invalidate()
        }
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        VStack(spacing: 20) {
            if audioViewModel.hasCompletedPlayback {
                ChapterCompletionView(thoughtId: thought.id)
            } else if audioViewModel.isFetchingLinks {
                fetchingLinksView
            } else if audioViewModel.player != nil {
                audioContentView
            } else if let error = audioViewModel.playerError {
                errorView(error)
            } else {
                readyView
            }
        }
        .padding()
    }
    
    // MARK: - Content States
    
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
            // Thought Info
            thoughtInfoView
            
            // Audio Controls
            audioControlsView
            
            // Subtitles
            subtitleView
            
            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("InitialSubtitleLoad"))) { notification in
            handleSubtitleNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSubtitles"))) { notification in
            handleSubtitleNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UpdateSubtitleTime"))) { notification in
            handleTimeUpdate(notification)
        }
    }
    
    private var thoughtInfoView: some View {
        VStack(spacing: 8) {
            Text(thought.name)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            if audioViewModel.currentChapterNumber > 0 {
                Text("Chapter \(audioViewModel.currentChapterNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Audio Controls
    
    private var audioControlsView: some View {
        VStack(spacing: 20) {
            // Main controls
            HStack(spacing: 40) {
                // Play/Pause button
                Button(action: {
                    audioViewModel.togglePlayback()
                }) {
                    Image(systemName: audioViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }
            }
            
            // Time labels
            if let player = audioViewModel.player {
                timeLabelsView(player: player)
            }
        }
    }
    
    private func timeLabelsView(player: AVPlayer) -> some View {
        HStack {
            Text(formatTime(currentTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
//        .onAppear {
//            startTimeUpdates(for: player)
//        }
        .onDisappear {
            timeUpdateTimer?.invalidate()
        }
    }
    
    // MARK: - Subtitle View
    
    private var subtitleView: some View {
        VStack(spacing: 20) {
            let subtitles = subtitleViewModel.currentSegment?.words ?? []
            
            Text("Debug: \(subtitles.count) words, current index: \(currentWordIndex)")
                .foregroundColor(.red)
                .font(.caption)
            
            if !subtitles.isEmpty {
                currentSubtitleView(subtitles: subtitles)
                progressIndicator(subtitles: subtitles)
            } else {
                Text("No subtitles available")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func currentSubtitleView(subtitles: [WordTimestamp]) -> some View {
        VStack(spacing: 8) {
            // Debug what getCurrentWordGroup returns
            if let wordGroup = getCurrentWordGroup(from: subtitles) {
                Text("Debug: Group has \(wordGroup.count) words")
                    .foregroundColor(.yellow)
                    .font(.caption)
                
                HStack(spacing: 4) {
                    ForEach(Array(wordGroup.enumerated()), id: \.offset) { index, wordTimestamp in
                        Text(wordTimestamp.text)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)  // Make it simple - just white
                            .padding(8)
                            .background(Color.red)  // Red background to see each word
                            .cornerRadius(4)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .background(Color.blue)  // Blue background for the whole word group
                .cornerRadius(8)
            } else {
                Text("Debug: No word group found")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(20)
                    .background(Color.green)  // Green background when no words
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color.purple)  // Purple background for entire subtitle view
        .cornerRadius(12)
    }
    
    private func progressIndicator(subtitles: [WordTimestamp]) -> some View {
        HStack {
            ForEach(0..<min(subtitles.count, 20), id: \.self) { index in
                Circle()
                    .fill(index <= currentWordIndex ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    // MARK: - Error and Ready Views
    
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
                audioViewModel.startListening(for: thought)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var readyView: some View {
        VStack(spacing: 16) {
            Text("Ready to Listen")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button("Start Listening") {
                audioViewModel.startListening(for: thought)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Status Overlay
    
    private var statusOverlayView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "headphones")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text(thought.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(statusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                if statusViewModel.thoughtStatus?.status != "not_started" {
                    Button("Resume") {
                        showStatusOverlay = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Restart") {
                    resetProgress()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
        .padding(32)
    }
    
    private var statusMessage: String {
        switch statusViewModel.thoughtStatus?.status ?? "not_started" {
        case "in_progress":
            return "You have partially listened to this thought. Would you like to resume where you left off or start over?"
        case "finished":
            return "You have already completed this thought. Would you like to listen again?"
        default:
            return "Ready to begin listening to this thought."
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkThoughtStatus() {
        statusViewModel.fetchThoughtStatus(thoughtId: thought.id) { status in
            DispatchQueue.main.async {
                determineNavigationAction(status: status)
            }
        }
    }
    
    private func determineNavigationAction(status: String) {
        switch status {
        case "not_started":
            showStatusOverlay = false
            audioViewModel.startListening(for: thought)
        case "in_progress", "finished":
            showStatusOverlay = true
        default:
            showStatusOverlay = false
        }
    }
    
    private func resetProgress() {
        statusViewModel.resetThoughtProgress(thoughtId: thought.id) { success in
            DispatchQueue.main.async {
                if success {
                    showStatusOverlay = false
                    audioViewModel.startListening(for: thought)
                } else {
                    print("Failed to reset progress")
                }
            }
        }
    }
    
    private func handleSubtitleNotification(_ notification: Notification) {
        if let data = notification.object as? [String: Any],
           let subtitlesURL = data["url"] as? String {
            print("Processing subtitle load: \(subtitlesURL)")
            fetchSubtitlePlaylist(playlistURL: subtitlesURL)
        }
    }
    
    private func handleTimeUpdate(_ notification: Notification) {
        if let globalTime = notification.object as? Double {
            // Update currentTime for UI display (use the raw chapter time)
            currentTime = globalTime  // Don't subtract durationsSoFar
            
            // Find correct segment for this time
            if let correctSegmentIndex = subtitleViewModel.segments.firstIndex(where: {
                globalTime >= $0.minStart && globalTime <= $0.maxEnd
            }) {
                print("🎵 Should be on segment \(correctSegmentIndex) (current: \(subtitleViewModel.currentSegmentIndex))")
                
                if correctSegmentIndex != subtitleViewModel.currentSegmentIndex {
                    subtitleViewModel.loadSegment(at: correctSegmentIndex)
                }
                
                // Only call updateCurrentWord once here
                if let currentSegment = subtitleViewModel.currentSegment {
                    updateCurrentWord(for: globalTime, subtitles: currentSegment.words)
                }
            } else {
                print("🎵 No segment found for time \(globalTime)")
            }
            
            subtitleViewModel.updateCurrentTime(globalTime)
        }
    }
    
    
    private func updateCurrentTime(from player: AVPlayer) {
        let current = player.currentTime().seconds
        if current.isFinite {
            currentTime = current
            // Calculate global time including previous chapters
            let globalTime = current + audioViewModel.durationsSoFar
            subtitleViewModel.updateCurrentTime(globalTime)
        }
    }
    
    private func startTimeUpdates(for player: AVPlayer) {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCurrentTime(from: player)
        }
    }
    
    
    private func updateCurrentWord(for globalTime: Double, subtitles: [WordTimestamp]) {
        guard !subtitles.isEmpty else { return }
        
        // Find word based on global time
        let newIndex = subtitles.lastIndex { $0.start <= globalTime } ?? 0
        
        print("🎵 Global time: \(globalTime), found index: \(newIndex)")
        if newIndex < subtitles.count {
            print("🎵 Word at index \(newIndex): '\(subtitles[newIndex].text)' (start: \(subtitles[newIndex].start))")
        }

        
        if newIndex != currentWordIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                previousWordIndex = currentWordIndex
                currentWordIndex = newIndex
            }
            
            // Submit biometric feedback when word changes
            if newIndex < subtitles.count {
                let currentWord = subtitles[newIndex]
                
                Task.detached(priority: .background) {
                    print("🎵 Submitting feedback for '\(currentWord.text)' - checking biometric value...")

                    
                    let result = await feedbackService.submitFeedback(
                        thoughtId: thought.id,
                        chapterNumber: audioViewModel.currentChapterNumber,
                        word: currentWord.text
                    )
                    
                    switch result {
                    case .success(_):
                        print("Feedback submitted for word: \(currentWord.text)")
                        break
                    case .failure(let error):
                        print("Feedback submission failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func getCurrentWordGroup(from subtitles: [WordTimestamp]) -> [WordTimestamp]? {
        guard !subtitles.isEmpty, currentWordIndex < subtitles.count else {
            print("🎵 getCurrentWordGroup: subtitles=\(subtitles.count), currentWordIndex=\(currentWordIndex)")
            return nil
        }
        
        let groupSize = 4
        let startIndex = max(0, currentWordIndex - groupSize/2)
        let endIndex = min(subtitles.count, startIndex + groupSize)
        
        let group = Array(subtitles[startIndex..<endIndex])
        print("🎵 Word group: \(group.map { $0.text })")
        
        return group
    }
    
    private func isCurrentWord(_ wordTimestamp: WordTimestamp, subtitles: [WordTimestamp]) -> Bool {
        guard currentWordIndex < subtitles.count else { return false }
        return subtitles[currentWordIndex].text == wordTimestamp.text
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Subtitle Processing (Simplified from AudioPlayerView)
    
    private func fetchSubtitlePlaylist(playlistURL: String) {
        print("🎵 Starting subtitle fetch for: \(playlistURL)")

        
        guard let url = URL(string: playlistURL) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Subtitle playlist fetch error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else { return }
            
            let vttFiles = extractVTTFiles(from: content, baseURL: playlistURL)
            
            DispatchQueue.main.async {
                processVTTFiles(vttFiles)
            }
        }.resume()
    }
    
    private func extractVTTFiles(from content: String, baseURL: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var vttFiles: [String] = []
        
        for line in lines {
            if line.hasSuffix(".vtt") {
                if line.hasPrefix("http") {
                    vttFiles.append(line)
                } else {
                    if let baseURL = URL(string: baseURL) {
                        let fullURL = baseURL.deletingLastPathComponent().appendingPathComponent(line).absoluteString
                        vttFiles.append(fullURL)
                    }
                }
            }
        }
        
        return vttFiles
    }
    
    private func processVTTFiles(_ vttFiles: [String]) {
        print("🎵 Processing \(vttFiles.count) VTT files")

        processVTTFile(at: 0, from: vttFiles, accumulated: [])
    }
    
    private func processVTTFile(at index: Int, from vttFiles: [String], accumulated: [SubtitleSegmentLink]) {
        guard index < vttFiles.count else {
            appendSegments(accumulated)
            return
        }
        
        let vttURL = vttFiles[index]
        
        determineSegmentTimes(vttURL: vttURL) { maybeLink in
            DispatchQueue.main.async {
                var newAccumulated = accumulated
                if let link = maybeLink {
                    newAccumulated.append(link)
                }
                
                processVTTFile(at: index + 1, from: vttFiles, accumulated: newAccumulated)
            }
        }
    }
    
    private func appendSegments(_ newSegments: [SubtitleSegmentLink]) {
        let existingURLs = Set(subtitleViewModel.segments.map { $0.urlString })
        let trulyNew = newSegments.filter { !existingURLs.contains($0.urlString) }
        let sortedNew = trulyNew.sorted { $0.minStart < $1.minStart }
        
        subtitleViewModel.segments.append(contentsOf: sortedNew)
        
        print("🎵 Segment ranges:")
        for (i, segment) in subtitleViewModel.segments.enumerated() {
            print("🎵 Segment \(i): \(segment.minStart) - \(segment.maxEnd)")
        }
        
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
                print("VTT fetch error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            let timeRegex = try! NSRegularExpression(pattern: #"(\d{2}):(\d{2}):(\d{2})\.(\d{3})"#)
            let lines = content.components(separatedBy: .newlines)
            
            var minStart: Double?
            var maxEnd: Double?
            
            for line in lines {
                if line.contains(" --> ") {
                    let matches = timeRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                    
                    if matches.count >= 2 {
                        let startMatch = matches[0]
                        let endMatch = matches[1]
                        
                        if let startTime = parseTime(from: line, match: startMatch),
                           let endTime = parseTime(from: line, match: endMatch) {
                            
                            if minStart == nil || startTime < minStart! {
                                minStart = startTime
                            }
                            if maxEnd == nil || endTime > maxEnd! {
                                maxEnd = endTime
                            }
                        }
                    }
                }
            }
            
            if let minStart = minStart, let maxEnd = maxEnd {
                let link = SubtitleSegmentLink(urlString: vttURL, minStart: minStart, maxEnd: maxEnd)
                completion(link)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func parseTime(from line: String, match: NSTextCheckingResult) -> Double? {
        let nsString = line as NSString
        
        guard match.numberOfRanges >= 5 else { return nil }
        
        let hoursRange = match.range(at: 1)
        let minutesRange = match.range(at: 2)
        let secondsRange = match.range(at: 3)
        let millisecondsRange = match.range(at: 4)
        
        guard hoursRange.location != NSNotFound,
              minutesRange.location != NSNotFound,
              secondsRange.location != NSNotFound,
              millisecondsRange.location != NSNotFound else { return nil }
        
        let hours = Int(nsString.substring(with: hoursRange)) ?? 0
        let minutes = Int(nsString.substring(with: minutesRange)) ?? 0
        let seconds = Int(nsString.substring(with: secondsRange)) ?? 0
        let milliseconds = Int(nsString.substring(with: millisecondsRange)) ?? 0
        
        return Double(hours * 3600 + minutes * 60 + seconds) + Double(milliseconds) / 1000.0
    }
}


// MARK: - WordTimestamp Model
//struct WordTimestamp {
//    let text: String
//    let start: Double
//    let end: Double
//}

struct WordTimestamp: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String
}
