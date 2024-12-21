import SwiftUI

struct ChapterCompletionView: View {
    let thoughtId: Int
    
    // For the animated fill
    @State private var fillAmount: CGFloat = 0.0
    // For showing the checkmark
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            // Keep the E-ink background behind everything
            Color("EInkBackground")
                .ignoresSafeArea()
            
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // 1) Green rectangle that grows from the bottom
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height * fillAmount
                        )
                        .animation(.easeInOut(duration: 2), value: fillAmount)
                    
                    // 2) Centered content: checkmark & message
                    VStack(spacing: 16) {
                        if showCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 100, height: 100)
                                .onAppear {
                                    // Haptic feedback
                                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                                    impact.impactOccurred()
                                }
                                // Pop-in animation
                                .transition(.scale)
                        }
                        
                        Text("You have finished exploring Thought \(thoughtId)")
                            .font(.title2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    // Begin the bottom fill after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            fillAmount = 1.0
                        }
                    }
                    // Show the checkmark after the fill completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation {
                            showCheckmark = true
                        }
                    }
                }
            }
        }
    }
}
