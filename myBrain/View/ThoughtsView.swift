import SwiftUI
import SwiftData
import Combine

struct ThoughtsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var viewModel: ThoughtsViewModel
    @StateObject private var socketViewModel: WebSocketViewModel

    @State private var processingThoughtIDs = Set<Int>()
    @State private var lastSocketMessage: String?
    @State private var selectedThought: Thought?
    @State private var isRefreshing = false
    @State private var lastScenePhase: ScenePhase = .active
    @State private var showDeviceDetail = false

    // Ear/Eye mode
    @State private var mode: Mode = .eye

    // Battery/Performance
    @State private var batteryLevel: Int?
    @State private var showPerformanceView = false
    @StateObject private var performanceVM = PerformanceViewModel()
    
    // "Connected" banner
    @State private var showConnectedBanner = false
    
    // Timer for battery level
    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(every: 6, on: .main, in: .common)
    @State private var batteryCancellable: AnyCancellable?

    // MARK: - Init
    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
        _socketViewModel = StateObject(wrappedValue: WebSocketViewModel(baseUrl: "brain.sorenapp.ir", token: accessToken))
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Adaptive background color (dark/light)
            if colorScheme == .dark {
                Color.black.ignoresSafeArea()
            } else {
                Color.white.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // MARK: - Top Section
                topSection
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // MARK: - Second Row (list title + mode switch + gear + brain)
                secondRow
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // MARK: - Content
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    scrollListView
                }

                // MARK: - Logout button at bottom
                Button(action: logoutAction) {
                    Text("Logout")
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
            }

            // MARK: - Overlays
            if isRefreshing {
                refreshOverlay
            }
            if showConnectedBanner {
                connectedBanner
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: logoutAction) {
                    Text("Logout")
                }
            }
        }
        .sheet(isPresented: $showDeviceDetail) {
            DeviceDetailView(bleManager: bleManager)
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // MARK: - Lifecycle
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
                // Show "Connected" banner for a moment
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
                handleSocketJSONMessage(jsonString: message)
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
        // Navigation Destinations
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

    // MARK: - Subviews

    /// Top section with a bigger headphone + battery above it, and the app title "MyBrain" to the right.
    private var topSection: some View {
         HStack(alignment: .top, spacing: 16) {
             // "MyBrain" title
             Text("MyBrain")
                 .font(.largeTitle)
                 .fontWeight(.bold)
                 .foregroundColor(.primary)
             
             Spacer()
             
             // Headphone + Battery in a vertical container
             VStack(spacing: 4) {
                 // Battery indicator (if connected)
                 if let battery = bleManager.batteryLevel {
                     Text("\(battery)%")
                         .font(.caption)
                         .foregroundColor(batteryColor(for: battery))
                 }
                 
                 // Headphone image - tappable to access device page
                 Button {
                     showDeviceDetail = true
                 } label: {
                     Image(colorScheme == .dark ? "headphone" : "headphone_b")
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .frame(width: 44, height: 44)
                         .opacity(bleManager.isConnected ? 1.0 : 0.6)
                 }
                 .buttonStyle(PlainButtonStyle())
             }
         }
     }

    /// Second row: "My Thoughts" on the left, and on the right a container for the mode switch + gear + brain icons (outside the container).
    private var secondRow: some View {
        HStack {
            // Left: List Title
            Text("My Thoughts")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()
            
            // Container with mode switch
            HStack(spacing: 8) {
                ModeSwitch(mode: $mode)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Gear icon (outside container)
            Image(systemName: "gearshape")
                .font(.title3)
                .onTapGesture {
                    print("Settings tapped")
                }

            // Brain icon (outside container)
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .onTapGesture {
                    showPerformanceView = true
                }
        }
    }

    /// Scrollable list of `ThoughtCard`
    private var scrollListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.thoughts) { thought in
                    ThoughtCard(thought: thought) { thoughtToDelete in
                        viewModel.deleteThought(thoughtToDelete)
                    }
                    .onTapGesture {
                        selectedThought = thought
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading Thoughts...")
            .tint(.white)
            .foregroundColor(.white)
            .padding(.top, 40)
    }

    private func errorView(message: String) -> some View {
        Text("Error: \(message)")
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    private var refreshOverlay: some View {
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
        .animation(.easeInOut, value: isRefreshing)
    }
    
    private var connectedBanner: some View {
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

    // MARK: - Functions

    private func refreshData() {
        isRefreshing = true
        fetchThoughts()
        socketViewModel.sendMessage(action: "list_thoughts", data: [:])
    }

    private func fetchThoughts() {
        viewModel.fetchThoughts()
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

    private func handleSocketJSONMessage(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                handleSocketMessage(message: jsonObject)
            }
        } catch {
            print("Failed to decode incoming message: \(error)")
        }
    }

    private func handleSocketMessage(message: [String: Any]) {
        guard let type = message["type"] as? String else {
            print("Could not get type from socket message")
            return
        }
        switch type {
        case "thought_update":
            handleThoughtUpdate(message: message)
        case "thoughts_list":
            handleThoughtsList(message: message)
        default:
            break
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

            if ["processing", "pending", "extracted", "enriched"].contains(status) {
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

    // MARK: - Battery & Performance
    private var batteryIconName: String {
        guard let batteryLevel = batteryLevel else {
            return "battery.0"
        }
        switch batteryLevel {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 1...25:   return "battery.25"
        case 0:        return "battery.0"
        default:       return "battery.0"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        if level > 70 {
            return .green
        } else if level > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func fetchBatteryLevel() {
        performanceVM.fetchBatteryLevel()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch battery level: \(error)")
                }
            }, receiveValue: { level in
                self.batteryLevel = level
            })
            .store(in: &performanceVM.cancellables)
    }
    
    private func startBatteryLevelTimer() {
        batteryCancellable = batteryLevelTimer
            .autoconnect()
            .sink { _ in
                fetchBatteryLevel()
            }
    }

    private func stopBatteryLevelTimer() {
        batteryCancellable?.cancel()
        batteryCancellable = nil
    }
}

// MARK: - Mode
enum Mode {
    case eye, ear
}

// MARK: - ModeSwitch (Ear/Eye Toggle)
struct ModeSwitch: View {
    @Binding var mode: Mode
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { mode = .ear }) {
                Image(systemName: "ear")
                    .foregroundColor(mode == .ear ? .white : .gray)
                    .padding(8)
                    .background(mode == .ear ? Color.gray : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button(action: { mode = .eye }) {
                Image(systemName: "eye")
                    .foregroundColor(mode == .eye ? .white : .gray)
                    .padding(8)
                    .background(mode == .eye ? Color.gray : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
