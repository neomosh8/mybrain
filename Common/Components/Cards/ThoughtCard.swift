import SwiftUI
import Combine

struct ThoughtCard: View {
    let thought: Thought
    private let baseUrl = "https://brain.sorenapp.ir"
    
    /// Called when user taps "Delete" - triggers a server call in your ViewModel
    var onDelete: (Thought) -> Void
    
    /// Whether the red "Delete" bar is showing
    @State private var showDeleteUI = false
    
    /// Image loading state
    @State private var coverImage: UIImage? = nil
    @State private var isLoadingImage: Bool = false
    @State private var imageLoadFailed: Bool = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // MARK: - Main Card
            HStack(alignment: .center, spacing: 16) {
                // 1) Cover Image
                coverImageView
                    .onAppear {
                        loadCoverImage()
                    }
                
                // 2) Title & Subtitle
                VStack(alignment: .leading, spacing: 8) {
                    Text(thought.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(relativeDateString(for: thought.created_at))
                        .font(.body)
                        .foregroundColor(
                            Color(UIColor { traitCollection in
                                // If the system is in Light Mode, return a darker gray
                                // Otherwise, return the system's default secondary label color
                                traitCollection.userInterfaceStyle == .light
                                ? .black
                                : .secondaryLabel
                            })
                        )
                }
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            
            // MARK: - Status Overlay (If not processed)
            .overlay(
                Group {
                    if thought.status != "processed" {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                            ProgressView("Loading...")
                                .tint(.white)
                        }
                    }
                }
            )
            
            // MARK: - Delete Overlay & Button
            if showDeleteUI {
                // (A) Clear overlay behind delete button
                Color.black
                    .opacity(0.01)        // nearly transparent
                    .ignoresSafeArea()    // covers entire card area
                    .onTapGesture {
                        withAnimation {
                            showDeleteUI = false
                        }
                    }
                
                // (B) The actual delete button
                VStack {
                    Spacer()
                    Button(role: .destructive) {
                        onDelete(thought)    // Call the delete
                        showDeleteUI = false
                    } label: {
                        Text("Delete")
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: showDeleteUI)
            }
        }
        // MARK: - Long Press => Show delete bar
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    withAnimation {
                        showDeleteUI = true
                    }
                }
        )
    }
    
    private var coverImageView: some View {
        Group {
            if isLoadingImage {
                ProgressView()
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if imageLoadFailed {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    private func loadCoverImage() {
        guard let coverPath = thought.cover, !coverPath.isEmpty, coverImage == nil, !isLoadingImage else {
            return
        }
        
        isLoadingImage = true
        let fullUrl = baseUrl + coverPath
        
        ImageLoader.loadImage(from: fullUrl)
            .sink(receiveValue: { receivedImage in
                self.isLoadingImage = false
                if let image = receivedImage {
                    self.coverImage = image
                } else {
                    self.imageLoadFailed = true
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - Date Utilities
func relativeDateString(for serverDateString: String) -> String {
    guard let date = parseISO8601Date(serverDateString) else {
        return serverDateString
    }
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

func parseISO8601Date(_ isoString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: isoString)
}
