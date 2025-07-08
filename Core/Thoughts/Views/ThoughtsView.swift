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
//    // MARK: - Init
//    init(viewModel: ThoughtsViewModel) {
//        _viewModel = StateObject(wrappedValue: viewModel)
//        _performanceVM = StateObject(wrappedValue: PerformanceViewModel())
//    }
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
