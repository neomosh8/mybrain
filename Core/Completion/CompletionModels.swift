import Foundation

struct FeedbackPoint: Identifiable {
    let id = UUID()
    let index: Int
    let label: String
    let value: Double
}
