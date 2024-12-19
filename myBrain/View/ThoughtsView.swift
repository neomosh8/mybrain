import SwiftUI

struct ThoughtsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var viewModel: ThoughtsViewModel

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(accessToken: String) {
        _viewModel = StateObject(wrappedValue: ThoughtsViewModel(accessToken: accessToken))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading Thoughts...")
            } else if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.thoughts) { thought in
                            ThoughtCard(thought: thought)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            viewModel.fetchThoughts()
        }
        .navigationTitle("Thoughts")
    }
}

struct ThoughtCard: View {
    let thought: Thought
    private let baseUrl = "https://brain.sorenapp.ir"

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                // Fetch the image
                AsyncImage(url: URL(string: baseUrl + (thought.cover ?? ""))) { imagePhase in
                    switch imagePhase {
                    case .empty:
                        ProgressView()
                            .frame(height: 100)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Text(thought.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(thought.description ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
            .shadow(radius: 2)

            // If the thought is processing, show a loading overlay
            if thought.status == "processing" {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.4))
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
