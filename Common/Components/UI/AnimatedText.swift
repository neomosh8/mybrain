import SwiftUI

// MARK: - Flow Layout
struct FlowLayout: Layout {
    let spacing: CGFloat = 4
    let lineSpacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(
            sizes: sizes,
            spacing: spacing,
            lineSpacing: lineSpacing,
            containerWidth: proposal.width ?? .infinity
        ).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(
            sizes: sizes,
            spacing: spacing,
            lineSpacing: lineSpacing,
            containerWidth: bounds.width
        ).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }
    
    private func layout(sizes: [CGSize], spacing: CGFloat, lineSpacing: CGFloat, containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var offsets: [CGPoint] = []
        var currentRowY: CGFloat = 0
        var currentRowX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for size in sizes {
            if currentRowX + size.width > containerWidth && currentRowX > 0 {
                currentRowY += currentRowHeight + lineSpacing
                currentRowX = 0
                currentRowHeight = 0
            }
            
            offsets.append(CGPoint(x: currentRowX, y: currentRowY))
            currentRowX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
            maxWidth = max(maxWidth, currentRowX - spacing)
        }
        
        let totalHeight = currentRowY + currentRowHeight
        return (offsets, CGSize(width: min(maxWidth, containerWidth), height: totalHeight))
    }
}

// MARK: - Preference Key
struct WordFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Gradient Pill
struct HighlightOverlay: View {
    var frame: CGRect
    var cornerRadius: CGFloat = 4
    var extraWidth: CGFloat = 5
    var extraHeight: CGFloat = 3
    var opacity: Double = 0.8
    var gradient: LinearGradient = LinearGradient(
        gradient: Gradient(colors: [Color.blue, Color.cyan]),
        startPoint: .leading,
        endPoint: .trailing
    )
    var animation: Animation = .spring(response: 0.3, dampingFraction: 0.8)
    
    var body: some View {
        if frame != .zero {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(gradient)
                .opacity(opacity)
                .frame(width: frame.width + extraWidth, height: frame.height + extraHeight)
                .position(x: frame.midX, y: frame.midY)
                .animation(animation, value: frame)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Unified model
public struct WordData: Identifiable, Hashable {
    public let id = UUID()
    public let originalIndex: Int
    public let text: String
    public var attributes: AttributeContainer
    public var startTime: TimeInterval?
    public var endTime: TimeInterval?
    
    public init(
        originalIndex: Int,
        text: String,
        attributes: AttributeContainer = AttributeContainer(),
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil
    ) {
        self.originalIndex = originalIndex
        self.text = text
        self.attributes = attributes
        self.startTime = startTime
        self.endTime = endTime
    }
    
    func attributedString(highlighted: Bool = false) -> AttributedString {
        var s = AttributedString(text)
        s.mergeAttributes(attributes)
        if highlighted { s.foregroundColor = .white }
        return s
    }
}

// MARK: - Word-Flow View
public struct AnimatedWordsView: View {
    let bottomPadding: CGFloat = 50
    public let paragraphs: [[WordData]]
    public let currentWordIndex: Int
    public var showOverlay: Bool = true
    @State private var highlightFrame: CGRect = .zero
    
    // MARK: - Initializers
    
    public init(
        paragraphs: [[WordData]],
        currentWordIndex: Int,
        showOverlay: Bool
    ) {
        self.paragraphs = paragraphs
        self.currentWordIndex = currentWordIndex
        self.showOverlay = showOverlay
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if showOverlay, highlightFrame != .zero {
                HighlightOverlay(frame: highlightFrame)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(paragraphs.indices, id: \.self) { pIndex in
                    FlowLayout() {
                        ForEach(paragraphs[pIndex], id: \.originalIndex) { wordData in
                            let isHighlighted = (wordData.originalIndex == currentWordIndex)
                            Text(wordData.attributedString(highlighted: isHighlighted))
                                .id(wordData.originalIndex)
                                .background(
                                    Group {
                                        if isHighlighted {
                                            GeometryReader { proxy in
                                                Color.clear
                                                    .preference(
                                                        key: WordFrameKey.self,
                                                        value: [wordData.originalIndex: proxy.frame(in: .named("container")).integral]
                                                    )
                                            }
                                        }
                                    }
                                )
                        }
                    }
                }
                Spacer().frame(height: bottomPadding)
            }
        }
        .coordinateSpace(name: "container")
        .onPreferenceChange(WordFrameKey.self) { new in
            if let frame = new[currentWordIndex] {
                highlightFrame = frame.integral
            }
        }
        .onChange(of: currentWordIndex) { _, _ in
            if highlightFrame == .zero { }
        }
    }
}

// MARK: - Capture word frames
extension View {
    func captureWordFrame(index: Int, in spaceName: AnyHashable) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: WordFrameKey.self,
                    value: [index: proxy.frame(in: .named(spaceName)).integral]
                )
            }
        )
    }
}
