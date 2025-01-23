//ThoughtView.swift
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
    @Environment(\.colorScheme) var colorScheme

    @State private var showConnectedBanner = false
    @State private var processingThoughtIDs = Set<Int>()
    @State private var lastSocketMessage: String?
    @State private var selectedThought: Thought?
    @State private var isRefreshing = false
    @State private var lastScenePhase: ScenePhase = .active
    @State private var mode: Mode = .eye
    @State private var batteryLevel: Int?
    @State private var showPerformanceView = false
    @StateObject private var performanceVM = PerformanceViewModel()

    // Timer for battery level
    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(every: 6, on: .main, in: .common)
    @State private var cancellable: AnyCancellable?

    // Carousel index
    @State private var currentIndex = 0

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
        _socketViewModel = StateObject(wrappedValue: WebSocketViewModel(baseUrl: "brain.sorenapp.ir", token: accessToken))
    }

    var body: some View {
        ZStack {
            // MARK: - Light/Dark Background
            if colorScheme == .dark {
                Image("DarkBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Image("LightBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

            // MARK: - Main content
            VStack { // Removed the spacing: 0 to use default
                Spacer() // Push everything down from the top
                // 1) Page title
                Text("Thoughts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 8) // added bottom padding

                // 2) Custom ultra-thin container with Mode Switch & Battery
                HStack(spacing: 8) {
                    ModeSwitch(mode: $mode)
                    
                    Button(action: {
                        showPerformanceView = true
                    }) {
                        Image(systemName: batteryIconName)
                            .foregroundColor(batteryColor)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
               .padding(.bottom, 16) // add some padding under the header

                // 3) Carousel or content below the header
                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else {
                        CarouselView(viewModel: viewModel,
                                     selectedThought: $selectedThought)
                    }
                }
               
                Button(action: logoutAction) {
                                    Text("Logout")
                                        .foregroundColor(.white)
                                }

                Spacer() // push everything up from bottom
            }
           .frame(maxWidth: .infinity, maxHeight: .infinity) // Take up the whole screen

            // MARK: - Refresh overlay
            if isRefreshing {
                VStack {
                    Text("Refreshing...")
                        .font(.callout)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - "Connected" Banner
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
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: logoutAction) {
                    Text("Logout")
                        .foregroundColor(.white)
                }
            }
        }
        // Keep the nav bar style dark/black if desired
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            refreshData()
            fetchBatteryLevel()
            startBatteryLevelTimer()
        }
        .onDisappear {
            stopBatteryLevelTimer()
        }
        // MARK: - Socket Observers
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
        // Refresh on becoming active
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && lastScenePhase != .active {
                refreshData()
            }
            lastScenePhase = newPhase
        }
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

    // MARK: - Battery Icon Name
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
    
    // MARK: - Battery Color
    private var batteryColor: Color {
        guard let level = batteryLevel else {
            return .gray
        }
        if level > 75 {
            return .green
        } else if level > 40 {
            return .yellow
        } else {
            return .red
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
    
    // MARK: - Logout
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

        if let index = viewModel.thoughts.firstIndex(where: { $0.id == id }) {
            var updatedThought = viewModel.thoughts[index]
            updatedThought.status = status
            
            var tempThoughts = viewModel.thoughts
            tempThoughts[index] = updatedThought
            viewModel.thoughts = tempThoughts

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
            self.currentIndex = 0
        }
    }
    
    // MARK: - Battery Level
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

// MARK: - Mode
enum Mode {
    case eye, ear
}

// MARK: - ModeSwitch
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
    }
}

// MARK: - Download Helper (unchanged)
func downloadUSDZFile(from remoteURL: URL, to filename: String, completion: @escaping (Result<URL, Error>) -> Void) {
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let localURL = cacheDirectory.appendingPathComponent(filename)
    
    if FileManager.default.fileExists(atPath: localURL.path) {
        completion(.success(localURL))
        return
    }
    
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
            try FileManager.default.moveItem(at: tempLocalURL, to: localURL)
            completion(.success(localURL))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}
