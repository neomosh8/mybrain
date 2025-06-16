import SwiftUI
import Combine

struct ThoughtCard: View {
    let thought: Thought
    let onTap: () -> Void
    
    var onDelete: ((Thought) -> Void)? = nil
    
    @State private var showDeleteUI = false
    
    var body: some View {
        ZStack {
            // MARK: - Main Card
            Button(action: {
                if !showDeleteUI {
                    onTap()
                }
            }) {
                HStack(spacing: 12) {
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
                            Text(formatDate(thought.createdAt))
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
            .disabled(showDeleteUI) // Disable tap when delete UI is showing
            
            // MARK: - Status Overlay (If not processed)
            if thought.status != "processed" {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                    ProgressView("Processing...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }
            
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
                        onDelete?(thought)    // Call the delete
                        showDeleteUI = false
                    } label: {
                        Text("Delete")
                            .bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
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
                    if onDelete != nil { // Only show delete UI if onDelete is provided
                        withAnimation {
                            showDeleteUI = true
                        }
                    }
                }
        )
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
