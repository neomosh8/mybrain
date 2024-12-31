import SwiftUI

struct CarouselView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var offset: CGFloat = 0
    @State private var offsetAtDragStart: CGFloat = 0
    @State private var currentIndex: Int = 0
    
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 500
    private let spacing: CGFloat = 0
    
    @ObservedObject var viewModel: ThoughtsViewModel
    @Binding var selectedThought: Thought?
    
    var body: some View {
        GeometryReader { outerGeo in
            let screenWidth = outerGeo.size.width
            let totalSpacing = spacing * CGFloat(viewModel.thoughts.count - 1)
            let contentWidth = CGFloat(viewModel.thoughts.count) * cardWidth + totalSpacing
            let initialOffset = (screenWidth - cardWidth) / 2
            
            HStack(spacing: spacing) {
                ForEach(Array(viewModel.thoughts.enumerated()), id: \.element.id) { index, thought in
                    GeometryReader { innerGeo in
                        let midX = innerGeo.frame(in: .global).midX
                        let centerX = screenWidth / 2
                        
                        let distance = abs(midX - centerX)
                        let scale = max(0.7, 1 - distance / 500)
                        let opacity = distance <= 20 ? 1.0 : Double(max(0.7, 1 - distance / 500))
                        
                        ThoughtCard(thought: thought)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .animation(.easeInOut(duration: 0.2), value: scale)
                            .onTapGesture {
                                // If you only want to check the status, remove the scale check:
                                if thought.status == "processed" {
                                    selectedThought = thought
                                }
                            }

                    }
                    .frame(width: cardWidth, height: cardHeight)
                }
            }
            .frame(width: contentWidth, height: outerGeo.size.height, alignment: .leading)
            .offset(x: offset + initialOffset)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Simple direct translation during drag
                        offset = offsetAtDragStart + value.translation.width
                    }
                    .onEnded { value in
                        let dragThreshold: CGFloat = 50 // Minimum drag distance to trigger page change
                        let dragDirection = value.translation.width
                        let velocity = value.predictedEndLocation.x - value.location.x
                        
                        // Determine if we should move to next/previous card
                        if abs(dragDirection) > dragThreshold || abs(velocity) > 100 {
                            if dragDirection > 0 && currentIndex > 0 {
                                currentIndex -= 1
                            } else if dragDirection < 0 && currentIndex < viewModel.thoughts.count - 1 {
                                currentIndex += 1
                            }
                        }
                        
                        // Calculate the target offset based on current index
                        let targetOffset = -CGFloat(currentIndex) * cardWidth
                        
                        // Adjust for center positioning
                        let adjustedOffset = targetOffset + (screenWidth - cardWidth) / 2 - initialOffset
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = adjustedOffset
                        }
                        
                        offsetAtDragStart = adjustedOffset
                        
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
            )
        }
        .padding(.vertical, 20)
        .onAppear {
            // Initialize with first card centered
            let screenWidth = UIScreen.main.bounds.width
            let initialCenter = (screenWidth - cardWidth) / 2
            offset = -initialCenter
            offsetAtDragStart = offset
            currentIndex = 0
        }
    }
}
