import SwiftUI

struct ThoughtCard: View {
    let thought: Thought
    let onTap: () -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    
    @State private var showDeleteMenu = false
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: thought.cover ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    @unknown default:
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
                    ScrollingTitleView(text: thought.name)
                    
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
                        
                        HStack(alignment: .center, spacing: 8) {
                            ProgressView(value: Double(progress.completed), total: Double(progress.total))
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 2)
                            
                            Spacer()
                            
                            StatusBadge(status: thought.status)
                        }
                        
                        if progress.completed > 0 {
                            Text("Chapter \(progress.completed) of \(progress.total)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                    } else {
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
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            if onDelete != nil {
                showDeleteMenu = true
            }
        }
        .actionSheet(isPresented: $showDeleteMenu) {
            ActionSheet(
                title: Text("Delete Thought"),
                message: Text("Are you sure you want to delete this thought? This action cannot be undone."),
                buttons: [
                    .destructive(Text("Delete")) {
                        onDelete?(thought)
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - Helper Properties
    
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

// MARK: - Scrolling Title Component
struct ScrollingTitleView: View {
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var shouldAnimate = false
    
    var body: some View {
        GeometryReader { geometry in
            Text(text)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeometry in
                        Color.clear
                            .onAppear {
                                textWidth = textGeometry.size.width
                                containerWidth = geometry.size.width
                                
                                if textWidth > containerWidth {
                                    shouldAnimate = true
                                    startScrolling()
                                }
                            }
                    }
                )
                .offset(x: offset)
                .clipped()
        }
        .frame(height: 22)
    }
    
    private func startScrolling() {
        guard shouldAnimate else { return }
        
        let totalDistance = textWidth + 50 // text width + padding
        let animationDuration: Double = max(3.0, totalDistance / 30)
        
        withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
            offset = -totalDistance
        }
    }
}

struct ContentWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
