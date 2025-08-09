import SwiftUI

// MARK: - Flow Layout
/// A simple word-wrapping layout used by both AnimatedParagraphView and AnimatedSubtitleView.
struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    
    init(spacing: CGFloat = 8, lineSpacing: CGFloat = 6) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }
    
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
    
    private func layout(
        sizes: [CGSize],
        spacing: CGFloat,
        lineSpacing: CGFloat,
        containerWidth: CGFloat
    ) -> (offsets: [CGPoint], size: CGSize) {
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
/// Collects the on-screen frames for words keyed by their original index.
struct WordFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}


/// A reusable gradient pill sized and positioned from a CGRect.
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
        // Do nothing when there is no target frame
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

// MARK: - Capture word frames (shared)
extension View {
    /// Records the view's frame (in the given named coordinate space) into `WordFrameKey` under the provided index.
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



/// Unified model for both timer-driven and audio-synced words.
public struct WordData: Identifiable, Hashable {
    public let id = UUID()
    public let originalIndex: Int
    public let text: String

    /// Styling attributes carried from paragraph parsing (Paragraph view uses these).
    public var attributes: AttributeContainer

    /// Audio timestamps (Subtitle view uses these). `nil` in paragraph mode.
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
}

public extension WordData {
    /// Convenience when you need an `AttributedString` from the stored `attributes`.
    func attributedString(highlighted: Bool = false) -> AttributedString {
        var s = AttributedString(text)
        s.mergeAttributes(attributes)
        if highlighted { s.foregroundColor = .white }
        return s
    }
}
