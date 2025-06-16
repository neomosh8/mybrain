import SwiftUI

struct ThoughtCard: View {
    let thought: Thought
    let onTap: () -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    
    @State private var showDeleteUI = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Cover Image
                AsyncImage(url: processedImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
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
                
                // Thought Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(thought.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text("Created:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(formatDate(thought.createdAt))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress info
                    if let progress = thought.progress {
                        HStack(spacing: 4) {
                            Text("\(progress.total) chapters")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(formatReadingTime(chapters: progress.total))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress bar and chapter indicator
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    .frame(height: 4)
                                
                                Spacer()
                                
                                StatusBadge(status: thought.status)
                            }
                            
                            if progress.completed > 0 {
                                Text("Chapter \(progress.completed) of \(progress.total)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                        }
                    } else {
                        // Fallback when no progress data
                        HStack {
                            Text(thought.description ?? "No description available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            StatusBadge(status: thought.status)
                        }
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
            return nil
        }
        
        if coverString.hasPrefix("http://") || coverString.hasPrefix("https://") {
            return URL(string: coverString)
        } else {
            let baseURL = "https://brain.sorenapp.ir"
            let fullURL = baseURL + (coverString.hasPrefix("/") ? coverString : "/" + coverString)
            return URL(string: fullURL)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return "Unknown"
    }
    
    private func formatReadingTime(chapters: Int) -> String {
        // Estimate ~20 minutes per chapter
        let totalMinutes = chapters * 20
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m reading time"
        } else {
            return "\(minutes)m reading time"
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor)
            )
    }
    
    private var statusText: String {
        switch status {
        case "pending": return "Pending"
        case "extracted", "enriched": return "Processing"
        case "processed": return "Ready"
        case "extraction_failed", "enrichment_failed", "processing_failed": return "Error"
        default: return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "extracted", "enriched": return .blue
        case "processed": return .green
        case "extraction_failed", "enrichment_failed", "processing_failed": return .red
        default: return .gray
        }
    }
}
