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

