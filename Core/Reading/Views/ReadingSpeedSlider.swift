import SwiftUICore
import SwiftUI

struct ReadingSpeedSlider: View {
    @Binding var speed: Double
    @Binding var position: CGPoint
    
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tortoise")
                .font(.caption)
                .offset(y: -5)
            
            Slider(value: $speed, in: 0.01...0.25)
                .frame(height: 120)
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: 0.5, y: 0.5)
                .clipped()
            
            Image(systemName: "hare")
                .font(.caption)
                .offset(y: 5)
        }
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    position = CGPoint(
                        x: position.x + value.translation.width,
                        y: position.y + value.translation.height
                    )
                }
        )
    }
}
