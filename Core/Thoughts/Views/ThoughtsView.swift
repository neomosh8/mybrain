//import SwiftUI
//import SwiftData
//import Combine
//
//struct ThoughtsView: View {
//    // MARK: - Environment & State
//    @EnvironmentObject var authVM: AuthViewModel
//    @Environment(\.dismiss) private var dismiss
//    @Environment(\.modelContext) private var modelContext
//    @Environment(\.scenePhase) private var scenePhase
//    @Environment(\.colorScheme) var colorScheme
//    @EnvironmentObject var bluetoothService: BluetoothService
//    @State private var showDeviceDetails = false
//    @StateObject private var viewModel: ThoughtsViewModel
//    
//    @State private var processingThoughtIDs = Set<Int>()
//    @State private var lastSocketMessage: String?
//    @State private var selectedThought: Thought?
//    @State private var isRefreshing = false
//    @State private var lastScenePhase: ScenePhase = .active
//    
//    // Ear/Eye mode
//    @State private var mode: Mode = .eye
//    
//    // Battery/Performance
//    @State private var batteryLevel: Int?
//    @State private var showPerformanceView = false
//    @StateObject private var performanceVM = PerformanceViewModel()
//    
//    // "Connected" banner
//    @State private var showConnectedBanner = false
//    
//    // Timer for battery level
//    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(
//        every: 6,
//        on: .main,
//        in: .common
//    )
//    @State private var batteryCancellable: AnyCancellable?
//    
//    // MARK: - Init
//    init(viewModel: ThoughtsViewModel) {
//        _viewModel = StateObject(wrappedValue: viewModel)
//        _performanceVM = StateObject(wrappedValue: PerformanceViewModel())
//    }
//    
//    // MARK: - Body
//    var body: some View {
//        ZStack {
//            // Adaptive background color (dark/light)
//            if colorScheme == .dark {
//                Color.black.ignoresSafeArea()
//            } else {
//                Color.white.ignoresSafeArea()
//            }
//            
//            VStack(spacing: 0) {
//                // MARK: - Top Section
//                topSection
//                    .padding(.horizontal, 16)
//                    .padding(.top, 8)
//                
//                // MARK: - Second Row (list title + mode switch + gear + brain)
//                secondRow
//                    .padding(.horizontal, 16)
//                    .padding(.top, 8)
//                
//                // MARK: - Content
//                if viewModel.isLoading {
//                    loadingView
//                } else if let error = viewModel.errorMessage {
//                    errorView(message: error)
//                } else {
//                    scrollListView
//                }
//                
//                // MARK: - Logout button at bottom
//                Button(action: logoutAction) {
//                    Text("Logout")
//                        .foregroundColor(.white)
//                        .padding(.vertical, 8)
//                        .padding(.horizontal, 16)
//                        .background(Color.red)
//                        .cornerRadius(8)
//                }
//                .padding(.top, 16)
//                .padding(.bottom, 20)
//            }
//            
//            // MARK: - Overlays
//            if isRefreshing {
//                refreshOverlay
//            }
//            if showConnectedBanner {
//                connectedBanner
//            }
//        }
//        .navigationBarHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button(action: logoutAction) {
//                    Text("Logout")
//                }
//            }
//        }
//        .toolbarBackground(Color.black, for: .navigationBar)
//        .toolbarColorScheme(.dark, for: .navigationBar)
//        // MARK: - Lifecycle
//        .onAppear {
//            refreshData()
//            fetchBatteryLevel()
//            startBatteryLevelTimer()
//            
//            // Subscribe to WebSocket connection state
//            let subscription = viewModel.observeConnectionState { state in
//                if case .connected = state {
//                    self.showConnectedBanner = true
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                        withAnimation {
//                            self.showConnectedBanner = false
//                        }
//                    }
//                }
//            }
//            
//            viewModel.storeSubscription(subscription)
//            
//            // Subscribe to WebSocket messages for processing state
//            let messageSubscription = viewModel.observeWebSocketMessages { message in
//                if let type = message["type"] as? String {
//                    if type == "thought_update",
//                       let data = message["data"] as? [String: Any],
//                       let thoughtData = data["thought"] as? [String: Any],
//                       let id = thoughtData["id"] as? Int,
//                       let status = thoughtData["status"] as? String {
//                        self.handleProcessingState(id: id, status: status)
//                    }
//                }
//            }
//            
//            viewModel.storeSubscription(messageSubscription)
//        }
//        .onDisappear {
//            stopBatteryLevelTimer()
//        }
//        // Refresh on becoming active
//        .onChange(of: scenePhase) { _, newPhase in
//            if newPhase == .active && lastScenePhase != .active {
//                refreshData()
//            }
//            lastScenePhase = newPhase
//        }
//        // Navigation Destinations
//        .navigationDestination(item: $selectedThought) { thought in
//            if mode == .eye {
//                ThoughtDetailView(
//                    thought: thought,
//                    webSocketService: viewModel.getWebSocketService()
//                )
//            } else {
//                StreamThoughtView(
//                    thought: thought,
//                    webSocketService: viewModel.getWebSocketService()
//                )
//            }
//        }
//        .navigationDestination(isPresented: $showPerformanceView) {
//            PerformanceView(viewModel: performanceVM)
//        }
//    }
//    
//    // MARK: - Subviews
//    
//    /// Top section with a bigger headphone + battery above it, and the app title "MyBrain" to the right.
//    private var topSection: some View {
//        HStack(alignment: .top, spacing: 16) {
//            // "MyBrain" title
//            Text("MyBrain")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//                .foregroundColor(.primary)
//            
//            Spacer()
//            
//            // Headphone + Battery in a vertical container
//            VStack(spacing: 4) {
//                // Device button - takes to device details
//                Button(action: {
//                    showDeviceDetails = true
//                }) {
//                    Image("Neurolink")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .frame(width: 44, height: 44)
//                        .overlay(
//                            Circle()
//                                .fill(
//                                    bluetoothService.isConnected ? Color.green : Color.red
//                                )
//                                .frame(width: 12, height: 12)
//                                .offset(x: 15, y: 15)
//                        )
//                }
//                .buttonStyle(PlainButtonStyle())
//            }
//        }
//        .sheet(isPresented: $showDeviceDetails) {
//            NavigationView {
//                DeviceDetailsView(bluetoothService: bluetoothService)
//                    .navigationBarTitleDisplayMode(.inline)
//                    .toolbar {
//                        ToolbarItem(placement: .navigationBarTrailing) {
//                            Button("Done") {
//                                showDeviceDetails = false
//                            }
//                        }
//                    }
//            }
//        }
//    }
//    
//    /// Second row: "My Thoughts" on the left, and on the right a container for the mode switch + gear + brain icons (outside the container).
//    private var secondRow: some View {
//        HStack {
//            // Left: List Title
//            Text("My Thoughts")
//                .font(.title2)
//                .foregroundColor(.secondary)
//            
//            Spacer()
//            
//            // Container with mode switch
//            HStack(spacing: 8) {
//                ModeSwitch(mode: $mode)
//            }
//            .padding(.horizontal, 8)
//            .padding(.vertical, 4)
//            .background(Color.secondary.opacity(0.2))
//            .clipShape(RoundedRectangle(cornerRadius: 8))
//            
//            // Gear icon (outside container)
//            Image(systemName: "gearshape")
//                .font(.title3)
//                .onTapGesture {
//                    print("Settings tapped")
//                }
//            
//            // Brain icon (outside container)
//            Image(systemName: "brain.head.profile")
//                .font(.title3)
//                .onTapGesture {
//                    showPerformanceView = true
//                }
//        }
//    }
//    
//    /// Scrollable list of `ThoughtCard`
//    private var scrollListView: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                ForEach(viewModel.thoughts) { thought in
//                    ThoughtCard(thought: thought) { thoughtToDelete in
//                        viewModel.deleteThought(thoughtToDelete)
//                    }
//                    .onTapGesture {
//                        selectedThought = thought
//                    }
//                }
//            }
//            .padding(.vertical, 16)
//            .padding(.horizontal, 16)
//        }
//    }
//    
//    private var loadingView: some View {
//        ProgressView("Loading Thoughts...")
//            .tint(.white)
//            .foregroundColor(.white)
//            .padding(.top, 40)
//    }
//    
//    private func errorView(message: String) -> some View {
//        Text("Error: \(message)")
//            .foregroundColor(.red)
//            .multilineTextAlignment(.center)
//            .padding()
//    }
//    
//    private var refreshOverlay: some View {
//        VStack {
//            Text("Refreshing...")
//                .font(.callout)
//                .bold()
//                .foregroundColor(.white)
//                .padding()
//                .background(Color.green)
//                .cornerRadius(8)
//                .padding(.top, 16)
//            Spacer()
//        }
//        .transition(.move(edge: .top).combined(with: .opacity))
//        .animation(.easeInOut, value: isRefreshing)
//    }
//    
//    private var connectedBanner: some View {
//        VStack {
//            Text("Connected")
//                .font(.callout)
//                .bold()
//                .foregroundColor(.white)
//                .padding()
//                .background(Color.green)
//                .cornerRadius(8)
//                .padding(.top, 16)
//            Spacer()
//        }
//        .transition(.move(edge: .top).combined(with: .opacity))
//        .animation(.easeInOut, value: showConnectedBanner)
//    }
//    
//    // MARK: - Functions
//    
//    private func refreshData() {
//        isRefreshing = true
//        viewModel.refreshData()
//        
//        // Auto-hide refresh overlay after delay
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            withAnimation {
//                self.isRefreshing = false
//            }
//        }
//    }
//    
//    private func logoutAction() {
//        authVM.logout(context: modelContext) { result in
//            switch result {
//            case .success:
//                break
//            case .failure(let error):
//                print("Failed to logout:", error)
//            }
//        }
//    }
//    
//    // Handle processing state for thoughts
//    private func handleProcessingState(id: Int, status: String) {
//        if ["processing", "pending", "extracted", "enriched"].contains(status) {
//            processingThoughtIDs.insert(id)
//        } else {
//            processingThoughtIDs.remove(id)
//        }
//    }
//    
//    // MARK: - Battery & Performance
//    private var batteryIconName: String {
//        guard let batteryLevel = batteryLevel else {
//            return "battery.0"
//        }
//        switch batteryLevel {
//        case 76...100: return "battery.100"
//        case 51...75:  return "battery.75"
//        case 26...50:  return "battery.50"
//        case 1...25:   return "battery.25"
//        case 0:        return "battery.0"
//        default:       return "battery.0"
//        }
//    }
//    
//    private var batteryColor: Color {
//        guard let level = batteryLevel else {
//            return .gray
//        }
//        if level > 75 {
//            return .green
//        } else if level > 40 {
//            return .yellow
//        } else {
//            return .red
//        }
//    }
//    
//    private func fetchBatteryLevel() {
//        performanceVM.fetchBatteryLevel()
//            .sink(receiveCompletion: { completion in
//                if case .failure(let error) = completion {
//                    print("Failed to fetch battery level: \(error)")
//                }
//            }, receiveValue: { level in
//                self.batteryLevel = level
//            })
//            .store(in: &performanceVM.cancellables)
//    }
//    
//    private func startBatteryLevelTimer() {
//        batteryCancellable = batteryLevelTimer
//            .autoconnect()
//            .sink { _ in
//                fetchBatteryLevel()
//            }
//    }
//    
//    private func stopBatteryLevelTimer() {
//        batteryCancellable?.cancel()
//        batteryCancellable = nil
//    }
//}
//
//
//
//// MARK: - Mode
//enum Mode {
//    case eye, ear
//}
//
//// MARK: - ModeSwitch (Ear/Eye Toggle)
//struct ModeSwitch: View {
//    @Binding var mode: Mode
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            Button(action: { mode = .ear }) {
//                Image(systemName: "ear")
//                    .foregroundColor(mode == .ear ? .white : .gray)
//                    .padding(8)
//                    .background(mode == .ear ? Color.gray : Color.clear)
//                    .clipShape(RoundedRectangle(cornerRadius: 8))
//            }
//            Button(action: { mode = .eye }) {
//                Image(systemName: "eye")
//                    .foregroundColor(mode == .eye ? .white : .gray)
//                    .padding(8)
//                    .background(mode == .eye ? Color.gray : Color.clear)
//                    .clipShape(
//                        RoundedRectangle(cornerRadius: 8, style: .continuous)
//                    )
//            }
//        }
//    }
//}
