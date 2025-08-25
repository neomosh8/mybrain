import AVFoundation
import Combine
import SwiftUI

struct ListeningView: View {
    let thought: Thought

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ListeningViewModel()
    @StateObject private var statusPickerController = BottomSheetPickerController()

    @State private var thoughtStatus: ThoughtStatus?
    @State private var isCheckingStatus = true
    @State private var cancellables = Set<AnyCancellable>()

    @State private var showFocusChart = true
    @State private var showDurationTimer = true
    @State private var showMenuPopup = false
    @State private var lastScrollTime: Date = .distantPast

    private var canTogglePlayback: Bool {
        return !viewModel.isFetchingLinks && viewModel.player != nil
            && !isCheckingStatus && !viewModel.hasCompletedAllChapters
    }

    private var playPauseIcon: String {
        return viewModel.isPlaying ? "pause.fill" : "play.fill"
    }

    private var playPauseText: String {
        return viewModel.isPlaying ? "Pause" : "Play"
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
        .overlay {
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
                        },
                    ]
                )
            }
        }
        .onAppear {
            checkThoughtStatus()
        }
        .onDisappear {
            viewModel.cleanup()

            NotificationCenter.default.post(
                name: .thoughtProgressUpdated,
                object: nil,
                userInfo: ["thoughtId": thought.id]
            )
        }
        .fullScreenCover(
            isPresented: .constant(viewModel.hasCompletedAllChapters)
        ) {
            CompletionView(
                thoughtId: thought.id,
                thoughtName: thought.name,
                onDismiss: {
                    dismiss()
                }
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

        if let currentChapter = viewModel.chapterManager.currentChapter {
            let totalChapters = status.progress.total
            return "Chapter \(currentChapter.number) of \(totalChapters)"
        }

        let totalChapters = status.progress.total
        if viewModel.chapterManager.chapters.isEmpty {
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
                if viewModel.isFetchingLinks {
                    loadingContentView
                } else if viewModel.player != nil {
                    listeningContent
                } else if let error = viewModel.playerError {
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
            if viewModel.isFetchingLinks {
                ProgressView("Fetching streaming links...")
                    .tint(.gray)
                    .foregroundColor(.black)
            } else {
                Button("Start Listening") {
                    viewModel.startListening(for: thought)
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
            ScrollViewReader { proxy in
                ScrollView {
                    AnimatedWordsView(
                        paragraphs: viewModel.paragraphs,
                        currentWordIndex: viewModel.currentWordIndex,
                        showOverlay: viewModel.currentWordIndex >= 0
                    )
                    .padding()
                }
                .onChange(of: viewModel.currentWordIndex) { _, newIndex in
                    guard newIndex >= 15 else { return }
                    let now = Date()
                    
                    guard now.timeIntervalSince(lastScrollTime) > 0.16 else {
                        return
                    }
                    lastScrollTime = now
                    
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .background(Color("ParagraphBackground"))
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("NewChapterWordsFromAudio")
            )
        ) { notification in
            handleNewChapterWords(notification)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("UpdateSubtitleTime")
            )
        ) { notification in
            handleTimeUpdate(notification)
        }
    }

    private func handleNewChapterWords(_ notification: Notification) {
        if let userInfo = notification.userInfo,
            let words = userInfo["words"] as? [[String: Any]]
        {

            viewModel.loadWordsFromChapterAudio(words: words)
        }
    }

    private func handleTimeUpdate(_ notification: Notification) {
        if let globalTime = notification.object as? Double {
            viewModel.updateCurrentTime(globalTime)
        }
    }

    private var durationTimerControl: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Duration: \(formatDuration(viewModel.currentTime))")
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
                        viewModel.togglePlayback()
                    }
                }
            }) {
                HStack(spacing: 6) {
                    ZStack {
                        Image(systemName: playPauseIcon)
                            .font(.system(size: 16, weight: .medium))
                            .animation(
                                .easeInOut(duration: 0.1),
                                value: playPauseIcon
                            )
                    }
                    .frame(width: 10)

                    ZStack {
                        Text(playPauseText)
                            .font(.system(size: 15, weight: .medium))
                            .animation(
                                .easeInOut(duration: 0.1),
                                value: playPauseText
                            )
                    }
                    .frame(width: 50)
                }
                .foregroundColor(canTogglePlayback ? .white : .gray)
                .frame(width: 90, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            canTogglePlayback
                                ? Color.blue : Color.gray.opacity(0.3)
                        )
                        .animation(
                            .easeInOut(duration: 0.1),
                            value: canTogglePlayback
                        )
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
                viewModel.startListening(for: thought)
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
                viewModel.startListening(for: thought)
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
            return
                "You're in the middle of listening to \"\(thought.name)\". Would you like to continue where you left off?"
        case "finished":
            return
                "You've completed listening to \"\(thought.name)\". Would you like to listen to it again?"
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
                    if status.status == "in_progress"
                        || status.status == "finished"
                    {
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
        viewModel.startListening(for: thought)
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
}
