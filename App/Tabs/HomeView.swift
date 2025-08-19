import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @EnvironmentObject var bluetoothService: BTService
    @ObservedObject var thoughtsViewModel: ThoughtsViewModel
    @StateObject private var settings = SettingsManager.shared
    
    @State private var selectedMode: ContentMode
    @State private var showDeviceCard = true
    @State private var selectedThought: Thought?

    // Search/Filter states
    @State private var showSearchField = false
    @State private var searchText = ""
    
    // Battery related states
    @State private var batteryLevel: Int?
    @State private var batteryCancellable: AnyCancellable?
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // Timer for battery level
    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(
        every: 300, // seconds
        on: .main,
        in: .common
    )
    
    var onNavigateToDevice: (() -> Void)?
    
    init(thoughtsViewModel: ThoughtsViewModel, onNavigateToDevice: (() -> Void)? = nil) {
        self.thoughtsViewModel = thoughtsViewModel
        self.onNavigateToDevice = onNavigateToDevice

        _selectedMode = State(initialValue: SettingsManager.shared.contentMode)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    TopAppBar(
                        showDeviceCard: $showDeviceCard,
                        onDeviceCardTapped: {
                            toggleDeviceCard()
                        }
                    )
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            ModeSelectionView(selectedMode: $selectedMode)
                            
                            // Thoughts Section
                            if thoughtsViewModel.isLoading && thoughtsViewModel.thoughts.isEmpty {
                                LoadingThoughtsView()
                            } else if let errorMessage = thoughtsViewModel.errorMessage, thoughtsViewModel.thoughts.isEmpty {
                                ErrorThoughtsView(message: errorMessage) {
                                    thoughtsViewModel.fetchThoughts()
                                }
                            } else {
                                VStack(spacing: 12) {
                                    ThoughtsListSection(
                                        showSearchField: $showSearchField,
                                        searchText: $searchText,
                                        thoughts: filteredThoughts,
                                        selectedMode: selectedMode,
                                        onThoughtTap: { thought in
                                            handleThoughtSelection(thought)
                                        },
                                        onDelete: { thought in
                                            thoughtsViewModel.deleteThought(thought)
                                        },
                                        onRetry: { thought in
                                            thoughtsViewModel.retryThought(thought)
                                        }
                                    )
                                }
                            }
                            
                            Color.clear.frame(height: 50)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
                
                if showDeviceCard {
                    VStack {
                        HStack {
                            Spacer()
                            
                            DeviceStatusCard(onCardTapped: {
                                onNavigateToDevice?()
                            })
                            .environmentObject(bluetoothService)
                            .padding(.horizontal, 20)
                            
                            Spacer()
                        }
                        .padding(.top, 60)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationDestination(item: $selectedThought) { thought in
            switch selectedMode {
            case .reading:
                ReadingView(thought: thought)
            case .listening:
                ListeningView(thought: thought)
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            stopBatteryLevelTimer()
        }
        .onChange(of: bluetoothService.isConnected) { _, isConnected in
            if isConnected {
                startBatteryLevelTimer()
                fetchBatteryLevel()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showDeviceCard = false
                    }
                }
            } else {
                stopBatteryLevelTimer()
                batteryLevel = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .thoughtProgressUpdated)) { notification in
            if let thoughtId = notification.userInfo?["thoughtId"] as? String {
                refreshThoughtStatus(thoughtId: thoughtId)
            }
        }
        .refreshable {
            thoughtsViewModel.fetchThoughts()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredThoughts: [Thought] {
        if searchText.isEmpty {
            return thoughtsViewModel.thoughts
        } else {
            return thoughtsViewModel.thoughts.filter { thought in
                thought.name.localizedCaseInsensitiveContains(searchText) ||
                (thought.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupView() {
        if thoughtsViewModel.thoughts.isEmpty {
            thoughtsViewModel.fetchThoughts()
        }
        
        if bluetoothService.isConnected && batteryCancellable == nil {
            startBatteryLevelTimer()
        }
    }
    
    // MARK: - Action Methods
    
    private func toggleDeviceCard() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showDeviceCard.toggle()
        }
    }
    
    // MARK: - Functions
    
    private func handleThoughtSelection(_ thought: Thought) {
        guard thought.status == "processed" else {
            print("Thought is not ready yet - Status: \(thought.status)")
            return
        }
        
        print("🎯 Navigating to thought: \(thought.name) in \(selectedMode.title) mode")
        selectedThought = thought
    }
    
    private func refreshThoughtStatus(thoughtId: String) {
        thoughtsViewModel.refreshThoughtStatus(thoughtId: thoughtId)
    }
    
    
    // MARK: - Battery Functions
    
    private func fetchBatteryLevel() {
        bluetoothService.readBatteryLevel()
        
        bluetoothService.$batteryLevel
            .compactMap { $0 }
            .sink { level in
                self.batteryLevel = level
            }
            .store(in: &cancellables)
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

// MARK: - Loading View
struct LoadingThoughtsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your thoughts...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Error View
struct ErrorThoughtsView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Connection Error")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                Button(action: onRetry) {
                    Text("Retry Connection")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Top App Bar
struct TopAppBar: View {
    @Binding var showDeviceCard: Bool
    let onDeviceCardTapped: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image("AppLogoSVG")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("myBrain")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("by Neocore")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            ConnectionStatusIndicator(onTapped: onDeviceCardTapped)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
}

// MARK: - Connection Status Indicator
struct ConnectionStatusIndicator: View {
    @EnvironmentObject var bluetoothService: BTService
    let onTapped: () -> Void
    
    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 6) {
                Circle()
                    .fill(bluetoothService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(bluetoothService.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(bluetoothService.isConnected ? .green : .red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((bluetoothService.isConnected ? Color.green : Color.red).opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Enhanced Device Status Card with Auto-Connect States
struct DeviceStatusCard: View {
    @EnvironmentObject var bluetoothService: BTService
    let onCardTapped: () -> Void
    
    @State private var isVisible = true
    @State private var autoConnectAttempted = false
    @State private var isCurrentlyConnecting = false
    @State private var connectionTimer: Timer?
    @State private var hideTimer: Timer?
    
    enum CardState {
        case connectingToSaved(deviceName: String)
        case tapToConnect
        case connected(deviceInfo: DeviceInfo)
        case connectionFailed
    }
    
    struct DeviceInfo {
        let name: String
        let serialNumber: String?
        let batteryLevel: Int?
    }
    
    private var currentState: CardState {
        let hasSavedDevice = UserDefaults.standard.string(forKey: "savedBluetoothDeviceID") != nil
        
        if bluetoothService.isConnected, let device = bluetoothService.connectedDevice {
            return .connected(deviceInfo: DeviceInfo(
                name: device.name,
                serialNumber: bluetoothService.serialNumber,
                batteryLevel: bluetoothService.batteryLevel
            ))
        } else if hasSavedDevice && (isCurrentlyConnecting || !autoConnectAttempted) {
            let deviceName = bluetoothService.connectedDevice?.name ?? "NeuroLink"
            return .connectingToSaved(deviceName: deviceName)
        } else if hasSavedDevice && autoConnectAttempted && !isCurrentlyConnecting && !bluetoothService.isConnected {
            return .connectionFailed
        } else {
            return .tapToConnect
        }
    }
    
    var body: some View {
        if isVisible {
            cardContent
                .onAppear {
                    handleInitialState()
                }
                .onChange(of: bluetoothService.isConnected) { _, isConnected in
                    connectionTimer?.invalidate()
                    
                    if isConnected {
                        isCurrentlyConnecting = false
                    }
                }
        }
    }
    
    private var cardContent: some View {
        Button(action: onCardTapped) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image("Neurolink")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.blue)
                    )
                
                cardTextContent
                
                Spacer()
                
                cardRightContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.top, 12)
            .background(
                MessageBubble()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var cardTextContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch currentState {
            case .connectingToSaved(let deviceName):
                Text("Connecting to \(deviceName)...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Please wait")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            case .tapToConnect:
                Text("Tap to Connect")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Connect your NeuroLink device")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            case .connected(let deviceInfo):
                Text(deviceInfo.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Serial: \(deviceInfo.serialNumber ?? "Loading...")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
            case .connectionFailed:
                Text("Connection Failed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text("Tap to connect")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var cardRightContent: some View {
        switch currentState {
        case .connectingToSaved:
            EmptyView()
            
        case .tapToConnect, .connectionFailed:
            EmptyView()
            
        case .connected(let deviceInfo):
            if let batteryLevel = deviceInfo.batteryLevel {
                BatteryIndicator(level: batteryLevel)
            }
        }
    }
    
    // MARK: - State Handling Methods
    
    private func handleInitialState() {
        // Auto-connect if we have a saved device
        if UserDefaults.standard.string(forKey: "savedBluetoothDeviceID") != nil && !bluetoothService.isConnected {
            triggerAutoConnect()
        }
    }
    
    private func triggerAutoConnect() {
        autoConnectAttempted = true
        isCurrentlyConnecting = true
        bluetoothService.autoConnect()
        
        // Set a timeout for connection attempt (10 seconds)
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            isCurrentlyConnecting = false
            if !bluetoothService.isConnected {
                print("Auto-connection timeout")
            }
        }
    }
    
    func showCard() {
        isVisible = true
    }
}

// MARK: - Battery Indicator Component
struct BatteryIndicator: View {
    let level: Int
    
    private var batteryColor: Color {
        switch level {
        case 75...100: return .green
        case 25...74: return .yellow
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 9) {
                ZStack{
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary, lineWidth: 1.5)
                        .frame(width: 24, height: 14)
                    
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(width: 2, height: 6)
                        .offset(x: 14)
                    
                    GeometryReader { geometry in
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(batteryColor)
                                .frame(width: max(2, geometry.size.width * CGFloat(level) / 100 - 4))
                            Spacer()
                        }
                        .padding(2)
                    }
                    .frame(width: 24, height: 14)
                }
                
                Text("\(level)%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(batteryColor)
            }
            
            Text("3h 24m left")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: – MessageBubble Shape
struct MessageBubble: Shape {
    var cornerRadius: CGFloat = 16
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 12
    var tailOffset: CGFloat = 30
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )
        path.addRoundedRect(
            in: bubbleRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        
        let tailStartX = rect.maxX - tailOffset - tailWidth
        let tailEndX = rect.maxX - tailOffset
        let tailMidX = rect.maxX - tailOffset - (tailWidth / 2)
        
        path.move(to: CGPoint(x: tailStartX, y: tailHeight))
        path.addLine(to: CGPoint(x: tailMidX, y: 0))
        path.addLine(to: CGPoint(x: tailEndX, y: tailHeight))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Mode Selection View
struct ModeSelectionView: View {
    @Binding var selectedMode: ContentMode
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ModeButton(
                    mode: .reading,
                    selectedMode: $selectedMode,
                    icon: "eye",
                    title: "Reading",
                    isLeft: true
                )
                
                ModeButton(
                    mode: .listening,
                    selectedMode: $selectedMode,
                    icon: "headphones",
                    title: "Listening",
                    isLeft: false
                )
            }
            .background(
                ZStack {
                    Color.gray.opacity(0.1)
                    
                    GeometryReader { geometry in
                        HStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width / 2 - 4)
                                .offset(x: selectedMode == .reading ? 2 : geometry.size.width / 2 + 2)
                                .animation(.easeInOut(duration: 0.2), value: selectedMode)
                            
                            Spacer()
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Mode Button
struct ModeButton: View {
    let mode: ContentMode
    @Binding var selectedMode: ContentMode
    let icon: String
    let title: String
    let isLeft: Bool
    
    private var isSelected: Bool {
        selectedMode == mode
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMode = mode
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content Mode Enum
enum ContentMode: String, CaseIterable {
    case reading = "reading"
    case listening = "listening"
    
    var title: String {
        switch self {
        case .reading: return "Reading"
        case .listening: return "Listening"
        }
    }
    
    var icon: String {
        switch self {
        case .reading: return "eye"
        case .listening: return "headphones"
        }
    }
}

// MARK: - Thoughts List Section
struct ThoughtsListSection: View {
    @Binding var showSearchField: Bool
    @Binding var searchText: String
    let thoughts: [Thought]
    let selectedMode: ContentMode
    let onThoughtTap: (Thought) -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    var onRetry: ((Thought) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            if showSearchField {
                SearchFieldView(
                    searchText: $searchText,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSearchField = false
                            searchText = ""
                        }
                    }
                )
            } else {
                ThoughtsHeaderView(
                    onSearchTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSearchField = true
                        }
                    }
                )
            }
            
            if thoughts.isEmpty {
                EmptyThoughtsView(isSearching: !searchText.isEmpty)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(thoughts) { thought in
                        ThoughtCard(
                            thought: thought,
                            onOpen: { onThoughtTap(thought) },
                            onDelete: onDelete,
                            onRetry: onRetry
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Thoughts Header View
struct ThoughtsHeaderView: View {
    let onSearchTap: () -> Void
    
    var body: some View {
        HStack {
            Text("Your Thoughts")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

// MARK: - Search Field View
struct SearchFieldView: View {
    @Binding var searchText: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search thoughts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

// MARK: - Empty Thoughts View
struct EmptyThoughtsView: View {
    let isSearching: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isSearching ? "magnifyingglass" : "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(isSearching ? "No thoughts found" : "No thoughts yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isSearching ? "Try adjusting your search terms" : "Add your first thought to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}


extension Notification.Name {
    static let thoughtProgressUpdated = Notification.Name("thoughtProgressUpdated")
}
