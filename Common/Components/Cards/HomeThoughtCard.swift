import SwiftUI

struct HomeThoughtCard: View {
    let thought: Thought
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: thought.cover ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "doc.text")
                                .foregroundColor(.gray)
                                .font(.title2)
                        )
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
