import SwiftUI

struct HistoryCard: View {
    var title: String
    var percentage: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text("\(Int(percentage))%")
                .font(.headline)
                .foregroundColor(colorForPercentage(percentage))
        }
        .padding()
        .frame(maxWidth: .infinity) // Makes the card full-width
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(color: Color.gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    /// Dynamically adjusts the green color intensity based on the percentage.
    private func colorForPercentage(_ percentage: Double) -> Color {
        // Ensure percentage is between 0 and 100
        let clampedPercentage = min(max(percentage, 0), 100)
        // Calculate green intensity (0.0 to 1.0)
        let greenIntensity = clampedPercentage / 100
        return Color(red: 1 - greenIntensity, green: greenIntensity, blue: 0.0)
    }
}
