import SwiftUI

// Model representing each history item
struct HistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let percentage: Double
}

struct HistoryView: View {
    // Sample data for the history list with book and article titles
    let historyItems: [HistoryItem] = [
        HistoryItem(title: "The SwiftUI Journey", percentage: 75),
        HistoryItem(title: "Understanding Combine in Swift", percentage: 90),
        HistoryItem(title: "Mastering iOS Development", percentage: 60),
        HistoryItem(title: "Optimizing Performance in SwiftUI", percentage: 85),
        HistoryItem(title: "Design Patterns in Swift", percentage: 70),
        HistoryItem(title: "Introduction to Async/Await", percentage: 95),
        HistoryItem(title: "Building Responsive Apps", percentage: 80),
        HistoryItem(title: "SwiftUI vs. UIKit: A Comprehensive Comparison", percentage: 65),
        HistoryItem(title: "Advanced Swift Techniques", percentage: 88),
        HistoryItem(title: "Implementing Dark Mode in iOS Apps", percentage: 92),
        HistoryItem(title: "Swift for Beginners", percentage: 78),
        HistoryItem(title: "Pro UIKit Development", percentage: 82),
        HistoryItem(title: "Concurrency in Swift", percentage: 69),
        HistoryItem(title: "UI/UX Principles for Developers", percentage: 73),
        HistoryItem(title: "Leveraging Swift Packages for Modular Development", percentage: 81),
        HistoryItem(title: "State Management in SwiftUI", percentage: 87),
        HistoryItem(title: "Animations and Transitions in SwiftUI", percentage: 79),
        HistoryItem(title: "Securing Your iOS Applications", percentage: 84),
        HistoryItem(title: "Integrating Swift with Backend Services", percentage: 77),
        HistoryItem(title: "Deploying Apps to the App Store: Best Practices", percentage: 91)
    ]
    var body: some View {
        VStack(alignment: .leading) {
            Text("How much more did you get out of each thought?")
                .font(.headline)
                .padding([.top, .leading, .trailing])
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(historyItems) { item in
                        HistoryCard(title: item.title, percentage: item.percentage)
                    }
                }
                .padding([.leading, .trailing, .bottom])
            }
        }
    }
}
