import SwiftUI
import SwiftData

struct ThoughtsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ThoughtsViewModel

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
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
        }
        .onAppear(perform: viewModel.fetchThoughts)
        .navigationTitle("Thoughts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            leadingToolbarItem
            trailingToolbarItem
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Subviews and Toolbar Items

extension ThoughtsView {
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
                    ThoughtCard(thought: thought)
                }
            }
            .padding()
        }
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
                // Once logged out, isAuthenticated = false in AuthViewModel
                // ContentView should react by showing login screen again
                break
            case .failure(let error):
                print("Failed to logout:", error)
            }
        }
    }
}
// MARK: - ThoughtCard

struct ThoughtCard: View {
    let thought: Thought
    private let baseUrl = "https://brain.sorenapp.ir"
    
    var body: some View {
        ZStack {
            backgroundImage
            bottomGradient
            titleText
        }
        .frame(height: 200) // Fixed height ensures a stable card size
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
        .overlay(overlayIfProcessing)
    }
    
    /// Loads and displays the thought's cover image, if available
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
                    .scaledToFill()          // Fill the entire frame
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()               // Ensure no overflow
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
    
    /// Adds a subtle gradient at the bottom to enhance text readability
    private var bottomGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, Color.black.opacity(0.7)]),
            startPoint: .center,
            endPoint: .bottom
        )
    }
    
    /// Displays the thought’s name at the bottom of the card
    private var titleText: some View {
        VStack {
            Spacer()
            Text(thought.name)
                .font(.headline)
                .foregroundColor(.white)
                .padding([.horizontal, .bottom], 8)
        }
    }
    
    /// If the thought is still processing, show a translucent overlay with a progress indicator
    @ViewBuilder
    private var overlayIfProcessing: some View {
        if thought.status == "processing" {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.4))
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
