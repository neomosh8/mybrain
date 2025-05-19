import SwiftUI

struct TrendView: View {
    @State private var progress: CGFloat = 0.0
    @State private var showDetailText: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // This HStack will animate the circle to the left and show the text on the right
            HStack {
                // Progress circle + percentage
                ZStack {

                    Circle()
                        .trim(from: 0.0, to: 1.1)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.8), .green.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 150, height: 150)
                        .animation(.easeInOut(duration: 2), value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.title)
                        .bold()
                }
                // Animate position when detail text appears
                .offset(x: showDetailText ? -10 : 0)
                .onAppear {
                    // Animate progress to 40%
                    withAnimation(.easeInOut(duration: 2)) {
                        progress = 0.5
                    }
                    // Show text after delay (once animation finishes)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut) {
                            showDetailText = true
                        }
                    }
                }
                
                // The text that slides in
                if showDetailText {
                    Text("You have reclaiming 30 minutes more out of every hour")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .transition(.move(edge: .trailing))
                }
            }
            .frame(height: 160) // Enough space to hold circle & text horizontally

            // Inside PerformanceView or a ViewModel

            let insights: [Insight] = [
                Insight(
                    title: "Enhanced Attention Span",
                    description: "Your attention span has increased from 12 to 19 seconds, allowing you to focus more effectively.",
                    iconName: "timer",
                    iconColor: .blue
                ),
                Insight(
                    title: "Optimal Focus Time",
                    description: "You are most attentive late at night after 11 PM. Plan demanding tasks during this time.",
                    iconName: "moon.fill",
                    iconColor: .indigo
                ),
                Insight(
                    title: "Energy Peaks",
                    description: "Your energy levels peak in the early afternoon, making it ideal for critical tasks.",
                    iconName: "bolt.fill",
                    iconColor: .yellow
                ),
                Insight(
                    title: "Relaxation Reminder",
                    description: "Incorporate mindful breaks to manage stress and recharge effectively.",
                    iconName: "leaf.arrow.circlepath",
                    iconColor: .green
                ),
                Insight(
                    title: "Consistency Matters",
                    description: "Develop consistent routines to maintain your improved focus and energy levels.",
                    iconName: "checkmark.seal.fill",
                    iconColor: .teal
                ),
                Insight(
                    title: "Goal Progress Tracking",
                    description: "Track your goals and celebrate milestones to stay motivated.",
                    iconName: "chart.bar.fill",
                    iconColor: .purple
                )
            ]

            
            // Horizontal scroll carousel of InsightCards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Iterate over the insights array
                    ForEach(insights) { insight in
                        InsightCard(
                            title: insight.title,
                            description: insight.description,
                            iconName: insight.iconName,
                            iconColor: insight.iconColor
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
}
// Insight.swift


struct Insight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
}
