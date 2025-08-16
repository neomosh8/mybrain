import SwiftUI
import Combine

struct ReadingView: View {
    let thought: Thought
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReadingViewModel()
    @StateObject private var statusPickerController = BottomSheetPickerController()
    
    @State private var thoughtStatus: ThoughtStatus?
    @State private var isCheckingStatus = true
    @State private var cancellables = Set<AnyCancellable>()
    
    @State private var showFocusChart = true
    @State private var showSpeedSlider = true
    @State private var showMenuPopup = false
    
    private var canTogglePlayback: Bool {
        return !viewModel.chapters.isEmpty && !isCheckingStatus
    }
    
    private var playPauseIcon: String { viewModel.isPlaying ? "pause.fill" : "play.fill" }
    private var playPauseText: String { viewModel.isPlaying ? "Pause" : "Play" }
    
    var body: some View {
        ZStack {
            if isCheckingStatus {
                loadingStatusView
            } else {
                mainReadingInterface
                statusPickerOverlay
            }
        }
        .appNavigationBar(
            title: thought.name,
            subtitle: chapterSubtitle,
            onBackTap: { dismiss() }
        ) {
            PopupMenuButton(isPresented: $showMenuPopup)
        }
        .overlay {
            if showMenuPopup {
                PopupMenu(
                    isPresented: $showMenuPopup,
                    menuItems: [
                        PopupMenuItem(icon: "chart.bar.xaxis", title: "Focus Chart", isOn: showFocusChart) { showFocusChart.toggle() },
                        PopupMenuItem(icon: "speedometer", title: "Speed Slider", isOn: showSpeedSlider) { showSpeedSlider.toggle() }
                    ]
                )
            }
        }
        .onAppear { checkThoughtStatus() }
        .onDisappear {
            viewModel.cleanup()
            NotificationCenter.default.post(
                name: .thoughtProgressUpdated,
                object: nil,
                userInfo: ["thoughtId": thought.id]
            )
        }
    }
    
    // MARK: - Computed
    private var floatingFocusChart: some View { FloatingFocusChart().zIndex(1000) }
    
    private var chapterSubtitle: String {
        guard let status = thoughtStatus,
              let currentChapter = viewModel.currentChapterIndex else { return "Loading..." }
        let currentChapterNumber = currentChapter + 1
        let totalChapters = status.progress.total
        return "Chapter \(currentChapterNumber) of \(totalChapters)"
    }
    
    private var loadingStatusView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.gray)
            Text("Checking reading status...").foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("EInkBackground"))
    }
    
    private var mainReadingInterface: some View {
        VStack(spacing: 0)  {
            ZStack {
                if viewModel.hasCompletedAllChapters {
                    ChapterCompletionView(
                        thoughtId: thought.id,
                        thoughtName: thought.name,
                        onDismiss: {
                            dismiss()
                        }
                    )
                } else if viewModel.chapters.isEmpty {
                    loadingContentView
                } else {
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
                            if newIndex >= 15 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                    .background(Color("ParagraphBackground"))
                }
                
                if showSpeedSlider { readingSpeedControl }
                if showFocusChart { floatingFocusChart }
            }
            .frame(maxHeight: .infinity)
            
            bottomControlBar
        }
        .blur(radius: statusPickerController.isPresented ? 3 : 0)
    }
    
    private var loadingContentView: some View {
        VStack(spacing: 16) {
            if viewModel.isLoadingChapter {
                ProgressView("Loading Chapter...")
                    .tint(.gray)
                    .foregroundColor(.black)
            } else {
                Button("Load Content") { viewModel.requestNextChapter() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
        )
    }
    
    private var readingSpeedControl: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "tortoise").font(.caption).foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { 0.6 - viewModel.readingSpeed },
                        set: { viewModel.readingSpeed = 0.6 - $0
                            if viewModel.isPlaying {
                                viewModel.togglePlayback()
                                viewModel.togglePlayback()
                            }
                        }
                    ),
                    in: 0.1...0.4
                )
                .accentColor(.primary)
                .disabled(!canTogglePlayback)
                Image(systemName: "hare").font(.caption).foregroundColor(.secondary)
            }
            .opacity(canTogglePlayback ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.2), value: canTogglePlayback)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(width: 280)
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
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark").font(.system(size: 16, weight: .medium))
                    Text("Bookmark").font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(.black).opacity(0.9))
                .frame(width: 120, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
                )
            }
            .opacity(0)
            
            Button {
                if canTogglePlayback {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.togglePlayback() }
                }
            } label: {
                HStack(spacing: 6) {
                    ZStack { Image(systemName: playPauseIcon).font(.system(size: 16, weight: .medium)) }
                        .frame(width: 10)
                    ZStack { Text(playPauseText).font(.system(size: 15, weight: .medium)) }
                        .frame(width: 50)
                }
                .foregroundColor(canTogglePlayback ? .white : .gray)
                .frame(width: 90, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(canTogglePlayback ? Color.blue : Color.gray.opacity(0.3))
                )
            }
            .disabled(!canTogglePlayback)
            
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet").font(.system(size: 16, weight: .medium))
                    Text("Chapters").font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color(.black).opacity(0.9))
                .frame(width: 120, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
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
            title: "Reading Options",
            controller: statusPickerController,
            onDismiss: { setupReading() }
        ) {
            VStack(spacing: 0) {
                statusMessage
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                Divider().background(Color.secondary.opacity(0.2))
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
                Button("Resume Reading") {
                    statusPickerController.close(); setupReading()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                
                Button("Restart from Beginning") { resetReadingProgress() }
                    .buttonStyle(SecondaryActionButtonStyle())
            } else {
                Button("Start Reading") { resetReadingProgress() }
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
    
    // MARK: - Networking helpers (unchanged)
    private var overlayMessage: String {
        guard let status = thoughtStatus?.status else { return "Ready to start reading \"\(thought.name)\"" }
        switch status {
        case "in_progress":
            return "You're in the middle of reading \"\(thought.name)\". Would you like to continue where you left off?"
        case "finished":
            return "You've completed reading \"\(thought.name)\". Would you like to read it again?"
        default:
            return "Ready to start reading \"\(thought.name)\""
        }
    }
    
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
                        self.setupReading()
                    }
                case .failure:
                    self.setupReading()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupReading() { viewModel.setup(for: thought) }
    
    private func resetReadingProgress() {
        statusPickerController.close()
        networkService.thoughts.resetThoughtProgress(thoughtId: thought.id)
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .success:
                    self.setupReading()
                case .failure(let error):
                    print("❌ Failed to reset progress: \(error)")
                }
            }
            .store(in: &cancellables)
    }
}
