import SwiftUI
import AVFoundation
import Combine

struct ListeningView: View {
    let thought: Thought
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioViewModel = AudioStreamingViewModel()
    @StateObject private var subtitleViewModel = SubtitleViewModel()
    @StateObject private var statusViewModel = ListeningStatusViewModel()
    @StateObject private var statusPickerController = BottomSheetPickerController()
    
    private let networkService = NetworkServiceManager.shared
    @EnvironmentObject var backgroundManager: BackgroundManager
    private let feedbackService: any FeedbackServiceProtocol = FeedbackService.shared
    
    @State private var thoughtStatus: ThoughtStatus?
    @State private var isCheckingStatus = true
    @State private var cancellables = Set<AnyCancellable>()
    
    @State private var showFocusChart = true
    @State private var showDurationTimer = true
    @State private var showMenuPopup = false
    @State private var previousWordIndex: Int = -1
    
    private var canTogglePlayback: Bool {
        return !audioViewModel.isFetchingLinks &&
        audioViewModel.player != nil &&
        !isCheckingStatus &&
        !audioViewModel.hasCompletedPlayback
    }
    
    
    private var playPauseIcon: String {
        return audioViewModel.isPlaying ? "pause.fill" : "play.fill"
    }
    
    private var playPauseText: String {
        return audioViewModel.isPlaying ? "Pause" : "Play"
    }
    
    var body: some View {
        ZStack {
            if isCheckingStatus {
                loadingStatusView
            } else {
                mainListeningInterface
                
                statusPickerOverlay
            }
        }
        .appNavigationBar(
            title: thought.name,
            subtitle: chapterSubtitle,
            onBackTap: {
                dismiss()
            }
        ) {
            PopupMenuButton(isPresented: $showMenuPopup)
        }
        .overlay{
            if showMenuPopup {
                PopupMenu(
                    isPresented: $showMenuPopup,
                    menuItems: [
                        PopupMenuItem(
                            icon: "chart.bar.xaxis",
                            title: "Focus Chart",
                            isOn: showFocusChart
                        ) {
                            showFocusChart.toggle()
                        },
                        PopupMenuItem(
                            icon: "timer",
                            title: "Duration Timer",
                            isOn: showDurationTimer
                        ) {
                            showDurationTimer.toggle()
                        }
                    ]
                )
            }
        }
        .onAppear {
            checkThoughtStatus()
        }
        .onDisappear {
            audioViewModel.cleanup()
            
            NotificationCenter.default.post(
                name: .thoughtProgressUpdated,
                object: nil,
                userInfo: ["thoughtId": thought.id]
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var floatingFocusChart: some View {
        FloatingFocusChart()
            .zIndex(1000)
    }
    
    private var chapterSubtitle: String {
        guard let status = thoughtStatus else {
            return "Loading..."
        }
        
        if let currentChapter = audioViewModel.chapterManager.currentChapter {
            let totalChapters = status.progress.total
            return "Chapter \(currentChapter.number) of \(totalChapters)"
        }
        
        let totalChapters = status.progress.total
        if audioViewModel.chapterManager.chapters.isEmpty {
            return "Preparing audio..."
        } else {
            return "Chapter 1 of \(totalChapters)"
        }
    }
    
    private var loadingStatusView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.gray)
            Text("Checking listening status...")
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("EInkBackground"))
    }
    
    private var mainListeningInterface: some View {
        VStack(spacing: 0) {
            ZStack {
                if audioViewModel.hasCompletedPlayback {
                    ChapterCompletionView(thoughtId: thought.id)
                } else if audioViewModel.isFetchingLinks {
                    loadingContentView
                } else if audioViewModel.player != nil {
                    listeningContent
                } else if let error = audioViewModel.playerError {
                    errorView(error)
                } else {
                    readyView
                }
                
                if showDurationTimer {
                    durationTimerControl
                }
                
                if showFocusChart {
                    floatingFocusChart
                }
            }
            .frame(maxHeight: .infinity)
            
            bottomControlBar
        }
        .blur(radius: statusPickerController.isPresented ? 3 : 0)
    }
    
    private var loadingContentView: some View {
        VStack(spacing: 16) {
            if audioViewModel.isFetchingLinks {
                ProgressView("Fetching streaming links...")
                    .tint(.gray)
                    .foregroundColor(.black)
            } else {
                Button("Start Listening") {
                    audioViewModel.startListening(for: thought)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var listeningContent: some View {
        VStack(spacing: 20) {
            if !subtitleViewModel.segments.isEmpty {
                AnimatedSubtitleView(
                    subtitleViewModel: subtitleViewModel,
                    currentTime: audioViewModel.currentTime,
                    thoughtId: thought.id,
                    chapterNumber: audioViewModel.chapterManager.currentChapter?.number ?? 1
                )
            }
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
    
    private var durationTimerControl: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Duration: \(formatDuration(audioViewModel.currentTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .opacity(canTogglePlayback ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.2), value: canTogglePlayback)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: 36)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
            .padding(.bottom, 24)
        }
    }
    
    private var bottomControlBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                // TODO: Add bookmark functionality
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 16, weight: .medium))
                    Text("Bookmark")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(.black).opacity(0.9))
                .frame(width: 120, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
            }
            .opacity(0)
            
            Button(action: {
                if canTogglePlayback {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        audioViewModel.togglePlayback()
                    }
                }
            }) {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: playPauseIcon)
                            .font(.system(size: 16, weight: .medium))
                            .animation(.easeInOut(duration: 0.1), value: playPauseIcon)
                    }
                    .frame(width: 10)
                    
                    ZStack {
                        Text(playPauseText)
                            .font(.system(size: 15, weight: .medium))
                            .animation(.easeInOut(duration: 0.1), value: playPauseText)
                    }
                    .frame(width: 50)
                }
                .foregroundColor(canTogglePlayback ? .white : .gray)
                .frame(width: 90, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canTogglePlayback ? Color.blue : Color.gray.opacity(0.3))
                        .animation(.easeInOut(duration: 0.1), value: canTogglePlayback)
                )
            }
            .disabled(!canTogglePlayback)
            
            Button(action: {
                // TODO: Add chapters functionality
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                    Text("Chapters")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(.black).opacity(0.9))
                .frame(width: 120, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
            }
            .opacity(0)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    private var statusPickerOverlay: some View {
        BottomSheetPicker(
            title: "Listening Options",
            controller: statusPickerController,
            onDismiss: {
                setupListening()
            }
        ) {
            VStack(spacing: 0) {
                statusMessage
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                Divider()
                    .background(Color.secondary.opacity(0.2))
                
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
    }
    
    private var statusMessage: some View {
        Text(overlayMessage)
            .font(.body)
            .multilineTextAlignment(.leading)
            .foregroundColor(.primary)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if thoughtStatus?.status == "in_progress" {
                Button("Resume Listening") {
                    statusPickerController.close()
                    setupListening()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                
                Button("Restart from Beginning") {
                    resetListeningProgress()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else {
                Button("Start Listening") {
                    resetListeningProgress()
                }
                .buttonStyle(PrimaryActionButtonStyle())
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
        .padding()
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
        .padding()
    }
    
    // MARK: - Helper Properties
    private var overlayMessage: String {
        guard let status = thoughtStatus?.status else {
            return "Ready to start listening to \"\(thought.name)\""
        }
        
        switch status {
        case "in_progress":
            return "You're in the middle of listening to \"\(thought.name)\". Would you like to continue where you left off?"
        case "finished":
            return "You've completed listening to \"\(thought.name)\". Would you like to listen to it again?"
        default:
            return "Ready to start listening to \"\(thought.name)\""
        }
    }
    
    // MARK: - Action Methods
    private func checkThoughtStatus() {
        isCheckingStatus = true
        
        networkService.thoughts.getThoughtStatus(thoughtId: thought.id)
            .receive(on: DispatchQueue.main)
            .sink { result in
                self.isCheckingStatus = false
                
                switch result {
                case .success(let status):
                    self.thoughtStatus = status
                    if status.status == "in_progress" || status.status == "finished" {
                        self.statusPickerController.open()
                    } else {
                        self.setupListening()
                    }
                case .failure(let error):
                    print(error)
                    self.setupListening()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupListening() {
        audioViewModel.startListening(for: thought)
    }
    
    private func resetListeningProgress() {
        statusPickerController.close()
        
        networkService.thoughts.resetThoughtProgress(thoughtId: thought.id)
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .success:
                    self.setupListening()
                case .failure(let error):
                    print("❌ Failed to reset progress: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Functions
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func handleSubtitleNotification(_ notification: Notification) {
        if let data = notification.object as? [String: Any],
           let subtitlesURL = data["url"] as? String {
            print("Processing subtitle load: \(subtitlesURL)")
            fetchSubtitlePlaylist(playlistURL: subtitlesURL)
        }
    }
    
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
            
            let vttFiles = self.extractVTTFiles(from: content, baseURL: playlistURL)
            
            DispatchQueue.main.async {
                self.processVTTFiles(vttFiles)
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
                
                self.processVTTFile(at: index + 1, from: vttFiles, accumulated: newAccumulated)
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
                let range = NSRange(location: 0, length: line.utf16.count)
                let matches = timeRegex.matches(in: line, range: range)
                
                for match in matches {
                    let timeString = String(line[Range(match.range, in: line)!])
                    let time = self.parseVTTTime(timeString)
                    
                    if minStart == nil || time < minStart! {
                        minStart = time
                    }
                    if maxEnd == nil || time > maxEnd! {
                        maxEnd = time
                    }
                }
            }
            
            if let start = minStart, let end = maxEnd {
                let link = SubtitleSegmentLink(urlString: vttURL, minStart: start, maxEnd: end)
                completion(link)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func parseVTTTime(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let secondsAndMs = components[2].components(separatedBy: ".")
        let seconds = Double(secondsAndMs[0]) ?? 0
        let milliseconds = secondsAndMs.count > 1 ? (Double(secondsAndMs[1]) ?? 0) / 1000.0 : 0
        
        return hours * 3600 + minutes * 60 + seconds + milliseconds
    }
    
    
    private func handleTimeUpdate(_ notification: Notification) {
        if let globalTime = notification.object as? Double {
            subtitleViewModel.preloadNextSegmentIfNeeded(currentTime: globalTime)
            
            // Find correct segment for this time
            if let correctSegmentIndex = subtitleViewModel.segments.firstIndex(where: {
                globalTime >= $0.minStart && globalTime <= $0.maxEnd
            }) {
                if correctSegmentIndex != subtitleViewModel.currentSegmentIndex {
                    subtitleViewModel.loadSegment(at: correctSegmentIndex)
                }
            }
            
            subtitleViewModel.updateCurrentTime(globalTime)
        }
    }
}

