import SwiftUI

struct ThoughtCard: View {
    let thought: Thought
    
    /// If `thought.cover` is a relative path, prepend your domain.
    /// If `thought.cover` is already a full URL, just use `URL(string: thought.cover!)`.
    private let baseUrl = "https://brain.sorenapp.ir"
    
    var body: some View {
        ZStack {
            // Glassy background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 2)

            // Card Content
            VStack(alignment: .leading, spacing: 8) {
                // Top image
                ZStack {
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
                                .frame(maxWidth: .infinity)
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
                }
                .frame(height: 180) // top image height
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Title (wraps to new line)
                Text(thought.name)
                    .font(.system(.title3, design: .default).bold())
                    .foregroundColor(.black)
                    .lineLimit(nil)         // allow unlimited lines
                    .multilineTextAlignment(.leading) // wrap lines to the right

                    .fixedSize(horizontal: false, vertical: true) // let text grow vertically
                    .padding(.horizontal, 8)
                
                // Date
                Text(relativeDateString(for: thought.created_at))
                    .font(.system(.footnote))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        // Card sizing & corner shape
        .frame(width: 220) // only fix the width, let height expand
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            // optional white border
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}
// MARK: - Date Helpers

/// Convert the server date string into a friendly label: "Today", "Yesterday", or "MMM d"
func relativeDateString(for serverDateString: String) -> String {
    guard let date = parseISO8601Date(serverDateString) else {
        return serverDateString // fallback if parse fails
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

/// Parse ISO8601 date strings like "2024-12-19T06:50:31.594633Z"
func parseISO8601Date(_ isoString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter.date(from: isoString)
}
