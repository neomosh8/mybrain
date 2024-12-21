import SwiftUI
import SwiftData

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

    private let columns = [
        GridItem(.flexible(), spacing: 32),
        GridItem(.flexible(), spacing: 32)
    ]

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
        _socketViewModel = StateObject(wrappedValue: WebSocketViewModel(baseUrl: "brain.sorenapp.ir", token: accessToken))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "e5effc"), // see "Color(hex:)" note below
                    Color(hex: "e7f0fd")
                ]),
                startPoint: .topLeading,    // diagonal start
                endPoint: .bottomTrailing   // diagonal end
            )
            .ignoresSafeArea()
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
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.thoughts) { thought in
                    let isClickable = (thought.status == "processed")
                    Button {
                        if isClickable {
                            selectedThought = thought
                        }
                    } label: {
                        // Call your new ThoughtCard (no isProcessing or id param)
                        ThoughtCard(thought: thought)
                    }
                    .disabled(!isClickable)
                    .opacity(isClickable ? 1 : 0.7)
                }
            }
            .padding(32)
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
            ModeSwitch(mode: $mode)
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
                
                let thought = Thought(
                    id: id,
                    name: name,
                    description: description,
                    content_type: content_type,
                    cover: cover,
                    status: status,
                    created_at: created_at,
                    updated_at: updated_at
                )
                tempThoughts.append(thought)
            }
        }
        
        DispatchQueue.main.async {
            self.viewModel.thoughts = tempThoughts
            self.isRefreshing = false
        }
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
