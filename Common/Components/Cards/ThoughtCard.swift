import SwiftUI

// MARK: - CardButtonStyle
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - ThoughtCard
struct ThoughtCard: View {
    let thought: Thought
    let onOpen: () -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        Button(action: onOpen) {
            ThoughtCardContent(thought: thought)
        }
        .buttonStyle(CardButtonStyle())
        .hoverEffect(.highlight)
        .accessibilityHint("Opens thought \(thought.name)")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete \"\(thought.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteThought() }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    @MainActor
    private func deleteThought() async {
        onDelete?(thought)
    }
}

// MARK: - ThoughtCardContent
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
                    
                    HStack(alignment: .center, spacing: 8) {
                        ProgressView(value: Double(progress.completed), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(height: 4)
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
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

// MARK: - StatusBadge
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


// MARK: - Helper Functions (keep your existing ones)
import Foundation

private func formatDate(_ isoString: String) -> String {
    let parserWithFrac = ISO8601DateFormatter()
    parserWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    let parserNoFrac = ISO8601DateFormatter()
    parserNoFrac.formatOptions = [.withInternetDateTime]
    
    let date = parserWithFrac.date(from: isoString)
            ?? parserNoFrac.date(from: isoString)
    
    guard let validDate = date else {
        return isoString
    }
    let display = DateFormatter()
    display.locale = Locale(identifier: "en_US_POSIX")
    display.dateFormat = "MMMM d, yyyy"
    return display.string(from: validDate)
}


private func formatReadingTime(chapters: Int) -> String {
    // ≈ 2 min / chapter
    let minutes = chapters * 2
    return minutes >= 60
        ? "\(minutes / 60)h \(minutes % 60)m reading time"
        : "\(minutes)m reading time"
}
