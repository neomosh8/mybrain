import SwiftUI


struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Updated ThoughtCard with Button
struct ThoughtCard: View {
    let thought: Thought
    let onOpen: () -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    
    @State private var showDeleteMenu = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        Button(action: onOpen) {
            ThoughtCardContent(thought: thought)
        }
        .buttonStyle(CardButtonStyle())
        .hoverEffect(.highlight)
        .accessibilityHint("Opens thought \(thought.name)")
        .confirmationDialog(
            "Delete Thought",
            isPresented: $showDeleteMenu,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                showDeleteConfirm = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(thought.name)'? This action cannot be undone.")
        }
        .confirmationDialog(
            "Delete \"\(thought.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteThought()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    @MainActor
    private func deleteThought() async {
        onDelete?(thought)
    }
}

// MARK: - Extracted Card Content
/// Extracted inner view to keep Button hierarchies clean
private struct ThoughtCardContent: View {
    let thought: Thought
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: thought.cover ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        placeholder
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(thought.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(thought.name)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 2) {
                        Text("Created:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text(formatDate(thought.createdAt))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    let progress = thought.progress
                    HStack(spacing: 4) {
                        Text("\(progress.total) chapters")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatReadingTime(chapters: progress.total))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .center, spacing: 4) {
                        ProgressView(value: Double(progress.completed), total: Double(progress.total))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 4)
                        
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        Spacer(minLength: 120)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            )
            
            StatusBadge(status: thought.status)
                .padding(16)
        }
    }
    
    private var placeholder: some View {
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
    }
}

// MARK: - Helper Functions (keep your existing ones)
private func formatDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
    
    if let date = formatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy"
        return displayFormatter.string(from: date)
    }
    return "Unknown"
}

private func formatReadingTime(chapters: Int) -> String {
    // Estimate ~2 minutes per chapter
    let totalMinutes = chapters * 2
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m reading time"
    } else {
        return "\(minutes)m reading time"
    }
}

// MARK: - Status Badge
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

