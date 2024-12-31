import SwiftUI
import QuickLook

struct ThoughtCard: View {
    let thought: Thought
    private let baseUrl = "https://brain.sorenapp.ir"

    // Holds local downloaded URL for the usdz, if any
    @State private var modelFileURL: URL? = nil
    @State private var isDownloading = false
    @State private var downloadError: String? = nil
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                
                // MARK: - Top: Either 3D or Cover Image
                ZStack {
                    if let modelPath = thought.model_3d,
                       modelPath != "none" {
                        
                        // If we have downloaded the model
                                                if let localURL = modelFileURL {
                                                    // Show SceneKit-based 3D preview
                                                    SceneKitView(localFileURL: localURL)
//                                                        .frame(width: 180, height: 180)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                                } else {
                                                    // If downloading, show spinner
                                                    if isDownloading {
                                                        ProgressView("Downloading model...")
                                                            .frame(width: 180, height: 180)
                                                    } else {
                                                        // Start download on appear
                                                        Color.gray.opacity(0.2)
                                                            .frame(width: 180, height: 180)
                                                            .onAppear {
                                                                downloadModelIfNeeded(modelPath)
                                                            }
                                                    }
                                                }
                    } else {
                        // Show cover image if model is none
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
//                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                // MARK: - Title
                Text(thought.name)
                    .font(.system(.title3).bold())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                
                // MARK: - Date
                Text(relativeDateString(for: thought.created_at))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            // Show overlay spinner if the status != "processed"
            Group {
                if thought.status != "processed" {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                        ProgressView("Loading...")
                            .tint(.white)
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
        .alert("Download Error", isPresented: .constant(downloadError != nil), actions: {
            Button("OK") { downloadError = nil }
        }, message: {
            Text(downloadError ?? "")
        })
    }
    
    // MARK: - Download Helper
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

// MARK: - Date Helpers (unchanged)
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
