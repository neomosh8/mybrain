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


    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
        _socketViewModel = StateObject(wrappedValue: WebSocketViewModel(baseUrl: "brain.sorenapp.ir", token: accessToken))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    thoughtsGrid
                }
            }
            
            if isRefreshing{
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
                }.transition(.move(edge: .top).combined(with: .opacity))
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
                // Hide the banner after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showConnectedBanner = false
                    }
                }
            }
        }
        .onChange(of: socketViewModel.chapterData) { newChapterData in
            if let chapterData = newChapterData{
                print("new chapter data: \(chapterData)")
            }
        }
        .onChange(of: lastSocketMessage) { newMessage in
             if let message = newMessage{
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
        .onChange(of: scenePhase){ newPhase in
            if newPhase == .active && lastScenePhase != .active {
                refreshData()
            }
            lastScenePhase = newPhase
        }
        .navigationTitle("Thoughts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            leadingToolbarItem
            trailingToolbarItem
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedThought) { thought in
            ThoughtDetailView(thought: thought, socketViewModel: socketViewModel)
        }
    }

    private var loadingView: some View {
        ProgressView("Loading Thoughts...")
            .tint(.white)
    }

    private func errorView(message: String) -> some View {
        Text("Error: \(message)")
            .foregroundColor(.red)
            .multilineTextAlignment(.center)
            .padding()
    }

    private var thoughtsGrid: some View {
           ScrollView {
               LazyVGrid(columns: columns, spacing: 10) {
                   ForEach(viewModel.thoughts) { thought in
                        let isClickable = thought.status == "processed"
                       Button {
                           if isClickable {
                               selectedThought = thought
                           }
                       } label: {
                            ThoughtCard(thought: thought, isProcessing: processingThoughtIDs.contains(thought.id), id: thought.id)
                        }
                        .disabled(!isClickable)
                        .opacity(isClickable ? 1 : 0.7)
                   }
               }
               .padding()
           }
           .refreshable {
            refreshData()
           }
       }
    
    func refreshData() {
        isRefreshing = true
        fetchThoughts()
        socketViewModel.sendMessage(action: "list_thoughts", data: [:])
    }
    
    func fetchThoughts() {
          viewModel.fetchThoughts()
    }

    private var leadingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
            }
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
    
    private func handleSocketMessage(message: [String: Any]) {
        guard let type = message["type"] as? String else {
            print("Could not get type from socket message")
            return
        }

        if type == "thought_update" {
            handleThoughtUpdate(message: message)
        } else if type == "thoughts_list"{
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
             if status == "processing" || status == "pending" || status == "extracted" || status == "enriched"{
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
                let thought = Thought(id: id, name: name, description: description, content_type: content_type, cover: cover, status: status, created_at: created_at, updated_at: updated_at)
                tempThoughts.append(thought)
            }
        }

        DispatchQueue.main.async {
            self.viewModel.thoughts = tempThoughts
            self.isRefreshing = false
        }
    }
}

// MARK: - ThoughtCard

struct ThoughtCard: View {
    let thought: Thought
    let isProcessing: Bool
    let id: Int
    private let baseUrl = "https://brain.sorenapp.ir"
    
    var body: some View {
        ZStack {
            backgroundImage
            bottomGradient
            titleText
            if isProcessing{
                overlayIfProcessing
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
        .id(id)
    }
    
    private var backgroundImage: some View {
        AsyncImage(url: URL(string: baseUrl + (thought.cover ?? ""))) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            case .failure:
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private var bottomGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, Color.black.opacity(0.7)]),
            startPoint: .center,
            endPoint: .bottom
        )
    }
    
    private var titleText: some View {
        VStack {
            Spacer()
            Text(thought.name)
                .font(.headline)
                .foregroundColor(.white)
                .padding([.horizontal, .bottom], 8)
        }
    }
    
    private var overlayIfProcessing: some View {
        ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.4))
                ProgressView()
                    .tint(.white)
            }
        }
}
