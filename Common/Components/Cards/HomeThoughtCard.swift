import SwiftUI

struct HomeThoughtCard: View {
    let thought: Thought
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: processedImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(let error):
                        // Show default icon on failure
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                VStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                    Text("No Image")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            )
                    case .empty:
                        // Show loading state
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    @unknown default:
                        // Fallback
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    print("📸 Loading image for '\(thought.name)' from URL: \(thought.cover ?? "nil")")
                    print("📸 Processed URL: \(processedImageURL?.absoluteString ?? "nil")")
                }
                
                // Thought Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(thought.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(thought.description ?? "No description available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        // Status indicator
                        StatusBadge(status: thought.status)
                        
                        Spacer()
                        
                        // Created date
                        Text(formatDate(thought.created_at))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Properties
    
    private var processedImageURL: URL? {
        guard let coverString = thought.cover, !coverString.isEmpty else {
            print("📸 No cover URL for thought '\(thought.name)'")
            return nil
        }
        
        // Handle relative URLs by adding base URL
        if coverString.hasPrefix("http://") || coverString.hasPrefix("https://") {
            return URL(string: coverString)
        } else {
            // Assume it's a relative path and add the base URL
            let baseURL = "https://brain.sorenapp.ir"
            let fullURL = baseURL + (coverString.hasPrefix("/") ? coverString : "/" + coverString)
            print("📸 Converting relative URL '\(coverString)' to '\(fullURL)'")
            return URL(string: fullURL)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return "Unknown"
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor.opacity(0.1))
            )
    }
    
    private var statusText: String {
        switch status {
        case "processed": return "Ready"
        case "processing": return "Processing"
        case "pending": return "Pending"
        case "error": return "Error"
        default: return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "processed": return .green
        case "processing": return .orange
        case "pending": return .blue
        case "error": return .red
        default: return .gray
        }
    }
}
