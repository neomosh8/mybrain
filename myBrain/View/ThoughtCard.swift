import SwiftUI
import QuickLook

struct ThoughtCard: View {
    let thought: Thought
    private let baseUrl = "https://brain.sorenapp.ir"

    /// Called when user taps "Delete" - triggers a server call in your ViewModel
    var onDelete: (Thought) -> Void

    // MARK: 3D model or cover image states
    @State private var modelFileURL: URL? = nil
    @State private var isDownloading = false
    @State private var downloadError: String? = nil

    // Whether the red "Delete" bar is showing
    @State private var showDeleteUI = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // MARK: - Card Background
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.regularMaterial)
                .shadow(radius: 8)

            // MARK: - Card Content
            VStack(alignment: .leading, spacing: 8) {
                // 1) 3D model or cover image
                ZStack {
                    if let modelPath = thought.model_3d,
                       modelPath != "none" {
                        if let localURL = modelFileURL {
                            // Show 3D preview in SceneKit
                            SceneKitView(localFileURL: localURL)
                                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                            // 1) Use a high-priority gesture
                                       .highPriorityGesture(
                                           DragGesture(minimumDistance: 0)
                                               .onChanged { _ in
                                                   // Do nothing. Just preventing the carousel from moving.
                                               }
                                               .onEnded { _ in
                                                   // Also do nothing or handle if you want.
                                               }
                                       )
                        } else {
                            // Download if needed
                            if isDownloading {
                                ProgressView("Downloading model...")
                                    .frame(width: 180, height: 180)
                            } else {
                                Color.gray.opacity(0.2)
                                    .frame(width: 180, height: 180)
                                    .onAppear {
                                        downloadModelIfNeeded(modelPath)
                                    }
                            }
                        }
                    } else {
                        // Show cover image if no 3D
                        AsyncImage(url: URL(string: baseUrl + (thought.cover ?? ""))) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.gray.opacity(0.3))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            case .failure:
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    }
                }

                // 2) Title
                Text(thought.name)
                    .font(.system(.title3).bold())
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                // 3) Date
                Text(relativeDateString(for: thought.created_at))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)

            // MARK: - Delete Overlay & Button
            if showDeleteUI {
                // (A) Clear overlay behind delete button
                //     Taps here will dismiss the delete UI
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
        // MARK: - Card Modifiers
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            // If status != processed, show a translucent overlay + spinner
            Group {
                if thought.status != "processed" {
                    ZStack {
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color.black.opacity(0.3))
                        ProgressView("Loading...")
                            .tint(.white)
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36)
                .stroke(Color.white, lineWidth: 1)
        )
        .alert("Download Error", isPresented: .constant(downloadError != nil)) {
            Button("OK") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
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
}



extension ThoughtCard {
    private func downloadModelIfNeeded(_ path: String) {
        guard let remoteURL = URL(string: baseUrl + path) else {
            return
        }
        isDownloading = true
        downloadUSDZFile(from: remoteURL, to: "model-\(thought.id).usdz") { result in
            DispatchQueue.main.async {
                isDownloading = false
                switch result {
                case .success(let localURL):
                    self.modelFileURL = localURL
                case .failure(let error):
                    self.downloadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Date Utils Example
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
