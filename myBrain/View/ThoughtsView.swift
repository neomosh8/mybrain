import SwiftUI
import SwiftData
import Combine

struct ThoughtsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ThoughtsViewModel
    @StateObject private var socketViewModel: WebSocketViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showConnectedBanner = false
    @State private var processingThoughtIDs = Set<Int>()
    @State private var lastSocketMessage: String?
    @State private var selectedThought: Thought?
    @State private var isRefreshing = false
    @State private var lastScenePhase: ScenePhase = .active
    @State private var mode: Mode = .eye // Initial mode
    @State private var batteryLevel: Int?
    @State private var showPerformanceView = false
    @StateObject private var performanceVM = PerformanceViewModel()
    
    // New property for timer
    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(every: 6, on: .main, in: .common) // 6 seconds
    
    @State private var cancellable: AnyCancellable?
    
    // Animation properties for background gradient
   @State private var gradientStart = UnitPoint(x: 0, y: 0)
   @State private var gradientEnd = UnitPoint(x: 1, y: 1)
    @State private var isAnimating = false


    private let columns = [
        GridItem(.flexible(), spacing: 30),
        GridItem(.flexible(), spacing: 30)
    ]
    
    private var batteryIconName: String {
        guard let batteryLevel = batteryLevel else {
            return "battery.0"
        }
        
        switch batteryLevel {
        case 76...100:
            return "battery.100"
        case 51...75:
            return "battery.75"
        case 26...50:
            return "battery.50"
        case 1...25:
            return "battery.25"
        case 0:
            return "battery.0"
        default:
            return "battery.0"
        }
    }
    
    private var batteryColor: Color {
        guard let level = batteryLevel else {
            return .gray // Or some default color
        }
        
        if level > 75 {
            return .green
        } else if level > 40 {
           return .yellow
        } else {
            return .red
        }
    }

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
        _socketViewModel = StateObject(wrappedValue: WebSocketViewModel(baseUrl: "brain.sorenapp.ir", token: accessToken))
    }

    var body: some View {
        ZStack {
            // Animated Gradient Background
            animatedGradientBackground()
            
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    thoughtsGrid
                }
            }
            
            if isRefreshing {
                VStack {
                    Text("Refreshing...")
                        .font(.callout)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.top, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Overlay a "Connected" banner if showConnectedBanner is true
            if showConnectedBanner {
                VStack {
                    Text("Connected")
                        .font(.callout)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.top, 16)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showConnectedBanner)
            }
        }
        .onAppear {
            refreshData()
            fetchBatteryLevel()
            startBatteryLevelTimer()
            startAnimatingGradient()
            
        }
        .onDisappear {
            stopBatteryLevelTimer()
           stopAnimatingGradient()
        }
        .onChange(of: socketViewModel.welcomeMessage) { newMessage in
            if let message = newMessage {
                print("Received welcome message from WS: \(message)")
                
                // Show the connected banner once welcome message is received
                showConnectedBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showConnectedBanner = false
                    }
                }
            }
        }
        .onChange(of: socketViewModel.chapterData) { newChapterData in
            if let chapterData = newChapterData {
                print("new chapter data: \(chapterData)")
            }
        }
        .onChange(of: lastSocketMessage) { newMessage in
            if let message = newMessage {
                if let data = message.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            handleSocketMessage(message: jsonObject)
                        }
                    } catch {
                        print("Failed to decode incoming message: \(error)")
                    }
                }
            }
        }
        .onReceive(socketViewModel.$incomingMessage) { message in
            if let message = message,
               let data = try? JSONSerialization.data(withJSONObject: message),
               let string = String(data: data, encoding: .utf8) {
                lastSocketMessage = string
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && lastScenePhase != .active {
                refreshData()
            }
            lastScenePhase = newPhase
        }
        .navigationTitle("Thoughts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            modeToolbarItem
            trailingToolbarItem
            batteryToolbarItem
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedThought) { thought in
            if mode == .eye {
                ThoughtDetailView(thought: thought, socketViewModel: socketViewModel)
            } else {
                StreamThoughtView(thought: thought, socketViewModel: socketViewModel)
            }
        }
        .navigationDestination(isPresented: $showPerformanceView) {
            PerformanceView(viewModel: performanceVM)
        }
    }
    
    // MARK: - Animated Gradient Background
    private func animatedGradientBackground() -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#EEF0F2"), // Bright Gray
                Color(hex: "#65AFFF")  // Slightly Dark White
            ]),
            startPoint: gradientStart,
            endPoint: gradientEnd
        )
        .ignoresSafeArea()
        .onAppear {
            startAnimatingGradient()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                startAnimatingGradient()
            } else {
                stopAnimatingGradient()
            }
        }
    }
    
    private func startAnimatingGradient() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
            // Move 30%
            gradientStart = UnitPoint(x: 0.5, y: 0.5)
            gradientEnd = UnitPoint(x: 1.5, y: 1.6)

        }
    }
    
    private func stopAnimatingGradient() {
        isAnimating = false
        withAnimation {
            gradientStart = UnitPoint(x: 0, y: 0)
            gradientEnd = UnitPoint(x: 1, y: 1)
        }
    }
    // MARK: - Loading View
    private var loadingView: some View {
        ProgressView("Loading Thoughts...")
            .tint(.white)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        Text("Error: \(message)")
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    // MARK: - Thoughts Grid
    private var thoughtsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(viewModel.thoughts) { thought in
                    let isClickable = (thought.status == "processed")
                    Button {
                        if isClickable {
                            selectedThought = thought
                        }
                    } label: {
                        ThoughtCard(thought: thought)
                           .padding(.vertical, 4)
                           .padding(.horizontal, 8)
                    }
                    .disabled(!isClickable)
                    .opacity(isClickable ? 1 : 0.7)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
        .refreshable {
            refreshData()
        }
    }
    
    // MARK: - Refresh
    func refreshData() {
        isRefreshing = true
        fetchThoughts()
        socketViewModel.sendMessage(action: "list_thoughts", data: [:])
    }
    
    // MARK: - Fetch
    func fetchThoughts() {
        viewModel.fetchThoughts()
    }
    
    // MARK: - Toolbar
    private var modeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack {
                ModeSwitch(mode: $mode)
            }
        }
    }
    
    private var batteryToolbarItem: some ToolbarContent {
         ToolbarItem(placement: .navigationBarLeading) {
             Button(action: {
                 showPerformanceView = true
             }) {
                Image(systemName: batteryIconName)
                   .foregroundColor(.white)
                   .padding(8)
                   .background(batteryColor)
                   .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var trailingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: logoutAction) {
                Text("Logout")
                    .foregroundColor(.white)
            }
        }
    }
    
    private func logoutAction() {
        authVM.logoutFromServer(context: modelContext) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Failed to logout:", error)
            }
        }
    }
    
    // MARK: - Handle Socket Messages
    private func handleSocketMessage(message: [String: Any]) {
        guard let type = message["type"] as? String else {
            print("Could not get type from socket message")
            return
        }

        if type == "thought_update" {
            handleThoughtUpdate(message: message)
        } else if type == "thoughts_list" {
            handleThoughtsList(message: message)
        }
        
        print("Incoming socket message : \(message)")
    }
    
    private func handleThoughtUpdate(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any],
              let thoughtData = data["thought"] as? [String: Any],
              let id = thoughtData["id"] as? Int,
              let status = thoughtData["status"] as? String else {
            print("Invalid data format in thought_update message")
            return
        }

        // Update the thought status in your viewModel.thoughts
        if let index = viewModel.thoughts.firstIndex(where: { $0.id == id }) {
            var updatedThought = viewModel.thoughts[index]
            updatedThought.status = status
            
            var tempThoughts = viewModel.thoughts
            tempThoughts[index] = updatedThought
            viewModel.thoughts = tempThoughts

            // Update processingThoughtIDs set
            if status == "processing"
                || status == "pending"
                || status == "extracted"
                || status == "enriched" {
                processingThoughtIDs.insert(id)
            } else {
                processingThoughtIDs.remove(id)
            }
        }
    }
    
    private func handleThoughtsList(message: [String: Any]) {
        guard let data = message["data"] as? [String: Any],
              let thoughtsData = data["thoughts"] as? [[String: Any]] else {
            print("Invalid data format in thoughts_list message")
            return
        }
        
        var tempThoughts: [Thought] = []
        for thoughtData in thoughtsData {
            if let id = thoughtData["id"] as? Int,
               let name = thoughtData["name"] as? String,
               let description = thoughtData["description"] as? String?,
               let content_type = thoughtData["content_type"] as? String,
               let cover = thoughtData["cover"] as? String?,
               let status = thoughtData["status"] as? String,
               let created_at = thoughtData["created_at"] as? String,
               let updated_at = thoughtData["updated_at"] as? String {
                let model3D = thoughtData["model_3d"] as? String ?? "none"
                let thought = Thought(
                    id: id,
                    name: name,
                    description: description,
                    content_type: content_type,
                    cover: cover,
                    status: status,
                    created_at: created_at,
                    updated_at: updated_at,
                    model_3d: model3D
                )
                tempThoughts.append(thought)
            }
        }
        
        DispatchQueue.main.async {
            self.viewModel.thoughts = tempThoughts
            self.isRefreshing = false
        }
    }
    
    private func fetchBatteryLevel() {
            performanceVM.fetchBatteryLevel()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("Failed to fetch battery level: \(error)")
                    }
                }, receiveValue: { level in
                    self.batteryLevel = level
                })
                .store(in: &performanceVM.cancellables)
    }
    
    
    // MARK: - Battery level timer
    
    private func startBatteryLevelTimer() {
        cancellable = batteryLevelTimer
            .autoconnect()
            .sink { _ in
                fetchBatteryLevel()
            }
    }
    
    private func stopBatteryLevelTimer() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - ModeSwitch

enum Mode {
    case eye, ear
}

struct ModeSwitch: View {
    @Binding var mode: Mode

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { mode = .ear }) {
                Image(systemName: "ear")
                    .foregroundColor(mode == .ear ? .white : .gray)
                    .padding(8)
                    .background(mode == .ear ? Color.gray : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
            }
            Button(action: { mode = .eye }) {
                Image(systemName: "eye")
                    .foregroundColor(mode == .eye ? .white : .gray)
                    .padding(8)
                    .background(mode == .eye ? Color.gray : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(4)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17,
                                  (int >> 4 & 0xF) * 17,
                                  (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16,
                                  int >> 8 & 0xFF,
                                  int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                                  int >> 16 & 0xFF,
                                  int >> 8 & 0xFF,
                                  int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

func downloadUSDZFile(from remoteURL: URL, to filename: String, completion: @escaping (Result<URL, Error>) -> Void) {
    // Decide where you want to store the file — e.g., Caches directory
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let localURL = cacheDirectory.appendingPathComponent(filename)
    
    // If it already exists, return immediately
    if FileManager.default.fileExists(atPath: localURL.path) {
        completion(.success(localURL))
        return
    }
    
    // Otherwise, download
    URLSession.shared.downloadTask(with: remoteURL) { tempLocalURL, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let tempLocalURL = tempLocalURL else {
            completion(.failure(NSError(domain: "InvalidTemporaryURL", code: 0)))
            return
        }
        
        do {
            // Move downloaded file to local cache path
            try FileManager.default.moveItem(at: tempLocalURL, to: localURL)
            completion(.success(localURL))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}
