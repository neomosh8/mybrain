import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var selectedMode: ContentMode = .reading
    @State private var showDeviceCard = true
    @State private var selectedThought: Thought?
    
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 1.0
    @State private var cardOffset: CGSize = .zero
    
    // Search/Filter states
    @State private var showSearchField = false
    @State private var searchText = ""
    
    @StateObject private var thoughtsViewModel = ThoughtsViewModel()
    
    // Battery related states
    @State private var batteryLevel: Int?
    @State private var batteryCancellable: AnyCancellable?
    
    // Timer for battery level
    private var batteryLevelTimer: Timer.TimerPublisher = Timer.publish(
        every: 300, // seconds
        on: .main,
        in: .common
    )
    
    var onNavigateToDevice: (() -> Void)?
    
    init(onNavigateToDevice: (() -> Void)? = nil) {
        self.onNavigateToDevice = onNavigateToDevice
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    TopAppBar(
                        showDeviceCard: $showDeviceCard,
                        onDeviceCardTapped: {
                            if showDeviceCard {
                                hideDeviceCardWithAnimation()
                            } else {
                                showDeviceCardWithAnimation()
                            }
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
                    }
                }
                .onTapGesture {
                    if showDeviceCard {
                        hideDeviceCardWithAnimation()
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
                            .scaleEffect(cardScale)
                            .opacity(cardOpacity)
                            .offset(cardOffset)
                            .padding(.horizontal, 20)
                            .onTapGesture {
                                // Prevent tap from propagating to background
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 80)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationDestination(item: $selectedThought) { thought in
            switch selectedMode {
            case .reading:
                ThoughtDetailView(thought: thought)
            case .listening:
                StreamThoughtView(thought: thought)
            }
        }
        .onAppear {
            if bluetoothService.isConnected {
                startBatteryLevelTimer()
                fetchBatteryLevel()
                
                bluetoothService.isDevelopmentMode = false
                bluetoothService.isConnected = true
            } else{
                bluetoothService.isDevelopmentMode = true
                bluetoothService.isConnected = false
                bluetoothService.batteryLevel = 0
            }
            
            
            if !AppStateManager.shared.hasShownHomeIntro {
                AppStateManager.shared.hasShownHomeIntro = true
                
                thoughtsViewModel.fetchThoughts()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    hideDeviceCardWithAnimation()
                }
            } else {
                showDeviceCard = false
            }
        }
        .onDisappear {
            stopBatteryLevelTimer()
        }
        .onChange(of: bluetoothService.isConnected) { _, isConnected in
            if isConnected {
                startBatteryLevelTimer()
                fetchBatteryLevel()
            } else {
                stopBatteryLevelTimer()
                batteryLevel = nil
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
    
    // MARK: - Animation Functions
    
    private func showDeviceCardWithAnimation() {
        cardScale = 0.1
        cardOpacity = 0.0
        cardOffset = CGSize(width: 150, height: -80)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showDeviceCard = true
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.05)) {
            cardScale = 1.0
            cardOpacity = 1.0
            cardOffset = .zero
        }
    }
    
    private func hideDeviceCardWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            cardScale = 0.1
            cardOpacity = 0.0
            cardOffset = CGSize(width: 150, height: -80)
        }
        
        withAnimation(.easeOut(duration: 0.2).delay(0.25)) {
            showDeviceCard = false
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
    
    
    // MARK: - Battery Functions
    
    private func fetchBatteryLevel() {
        let level = 30
//        performanceVM.fetchBatteryLevel()
//            .sink(receiveCompletion: { completion in
//                if case .failure(let error) = completion {
//                    print("Failed to fetch battery level: \(error)")
//                }
//            }, receiveValue: { level in
                self.batteryLevel = level
                self.bluetoothService.batteryLevel = level
//            })
//            .store(in: &performanceVM.cancellables)
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
    @EnvironmentObject var bluetoothService: BluetoothService
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

// MARK: - Device Status Card
struct DeviceStatusCard: View {
    @EnvironmentObject var bluetoothService: BluetoothService
    let onCardTapped: () -> Void
    
    var body: some View {
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetoothService.isConnected ?
                         (bluetoothService.connectedDevice?.name ?? "Unknown Device") :
                         "Not Connected")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Model: NL-2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if bluetoothService.isConnected {
                    BatteryIndicator(level: bluetoothService.batteryLevel ?? 0)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Battery Indicator
struct BatteryIndicator: View {
    let level: Int
    
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
    
    private var batteryColor: Color {
        switch level {
        case 76...100: return .green
        case 26...75: return .orange
        default: return .red
        }
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
enum ContentMode: CaseIterable {
    case reading
    case listening
    
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
