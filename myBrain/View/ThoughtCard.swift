import SwiftUI

struct ThoughtCard: View {
    let thought: Thought
    
    /// If 'cover' is a relative path, prepend your domain here.
    /// If it's a full URL already, remove `baseUrl +`.
    private let baseUrl = "https://brain.sorenapp.ir"
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 2)
            
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
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Title
                Text(thought.name)
                    .font(.system(.title3).bold())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                
                // "Created at" date
                Text(relativeDateString(for: thought.created_at))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 220) // let height expand
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            // Overlay spinner if status != "processed"
            Group {
                if thought.status != "processed" {
                    ZStack {
                        // Translucent layer
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                        // Spinner
                        ProgressView("Loading...")
                            .tint(.white)
                    }
                }
            }
        )
        .overlay(
            // Optional white border
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

// MARK: - Date Helpers
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
