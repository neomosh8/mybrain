import SwiftUI

struct CarouselView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var offset: CGFloat = 0
    @State private var offsetAtDragStart: CGFloat = 0
    
    private let cardWidth: CGFloat = 240
    private let cardHeight: CGFloat = 500
    private let spacing: CGFloat = 0
    
    @ObservedObject var viewModel: ThoughtsViewModel
    @Binding var selectedThought: Thought?
    
    var body: some View {
        GeometryReader { outerGeo in
            let screenWidth = outerGeo.size.width
            let totalSpacing = spacing * CGFloat(viewModel.thoughts.count - 1)
            let contentWidth = CGFloat(viewModel.thoughts.count) * cardWidth + totalSpacing
            
            // Calculate the initial offset to center the first card
            let initialOffset = (screenWidth - cardWidth) / 2
            
            HStack(spacing: spacing) {
                ForEach(viewModel.thoughts) { thought in
                    GeometryReader { innerGeo in
                        let midX = innerGeo.frame(in: .global).midX
                        let centerX = screenWidth / 2
                        
                        let distance = abs(midX - centerX)
                        // Adjust scale calculation to ensure center card is at full scale
                        let scale = max(0.7, 1 - distance / 500)
                        // Adjust opacity calculation to ensure center card is fully opaque
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
                DragGesture()
                    .onChanged { value in
                        offset = offsetAtDragStart + value.translation.width
                    }
                    .onEnded { value in
                        let cardWithSpacing = cardWidth + spacing
                        
                        // Calculate the current center position relative to content
                        let currentCenter = -offset - initialOffset + screenWidth / 2
                        let currentIndex = currentCenter / cardWithSpacing
                        let targetIndex = round(currentIndex)
                        
                        // Calculate the target offset that will center the card
                        let targetOffset = -(targetIndex * cardWithSpacing - screenWidth / 2 + cardWidth / 2)
                        
                        // Add bounds checking
                        let minOffset = -(contentWidth - screenWidth)
                        let boundedOffset = max(minOffset, min(0, targetOffset))
                        
                        withAnimation(.easeOut) {
                            offset = boundedOffset - initialOffset
                        }
                        
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        
                        offsetAtDragStart = offset
                    }
            )
        }
        .padding(.vertical, 20)
        .onAppear {
            // Start with first card centered
            let screenWidth = UIScreen.main.bounds.width
            offset = -(screenWidth - cardWidth) / 2
            offsetAtDragStart = offset
        }
    }
}
