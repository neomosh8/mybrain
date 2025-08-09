import SwiftUI

// MARK: - Flow Layout
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




/// A reusable word-flow view used by both the paragraph and subtitle screens.
public struct AnimatedWordsView: View {
    // Data / state
    public let paragraphs: [[WordData]]
    public let currentWordIndex: Int
    
    // Layout
    public var spacing: CGFloat = 4
    public var lineSpacing: CGFloat = 6
    public var bottomPadding: CGFloat = 50
    public var wordFont: Font? = nil
    
    // Overlay gating
    public var showOverlay: Bool = true
    
    // External state (optional). If nil, the view manages its own state.
    private var wordFramesBinding: Binding<[Int: CGRect]>?
    private var highlightFrameBinding: Binding<CGRect>?
    
    // Internal backing state when bindings are not provided
    @State private var _wordFrames: [Int: CGRect] = [:]
    @State private var _highlightFrame: CGRect = .zero
    
    // MARK: - Initializers
    
    /// Use this when the parent wants to **own** frames/highlightFrame (e.g., subtitle screen).
    public init(
        paragraphs: [[WordData]],
        currentWordIndex: Int,
        showOverlay: Bool,
        wordFont: Font? = nil,
        spacing: CGFloat = 4,
        lineSpacing: CGFloat = 6,
        bottomPadding: CGFloat = 50,
        wordFrames: Binding<[Int: CGRect]>,
        highlightFrame: Binding<CGRect>
    ) {
        self.paragraphs = paragraphs
        self.currentWordIndex = currentWordIndex
        self.showOverlay = showOverlay
        self.wordFont = wordFont
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.bottomPadding = bottomPadding
        self.wordFramesBinding = wordFrames
        self.highlightFrameBinding = highlightFrame
    }
    
    /// Use this when the view can **manage its own** frames/highlightFrame (e.g., paragraph screen).
    public init(
        paragraphs: [[WordData]],
        currentWordIndex: Int,
        showOverlay: Bool,
        wordFont: Font? = nil,
        spacing: CGFloat = 4,
        lineSpacing: CGFloat = 6,
        bottomPadding: CGFloat = 50
    ) {
        self.paragraphs = paragraphs
        self.currentWordIndex = currentWordIndex
        self.showOverlay = showOverlay
        self.wordFont = wordFont
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.bottomPadding = bottomPadding
        self.wordFramesBinding = nil
        self.highlightFrameBinding = nil
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            if showOverlay, highlightFrame != .zero {
                HighlightOverlay(frame: highlightFrame)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(paragraphs.indices, id: \.self) { pIndex in
                    FlowLayout(spacing: spacing, lineSpacing: lineSpacing) {
                        ForEach(paragraphs[pIndex], id: \.originalIndex) { wordData in
                            let isHighlighted = (wordData.originalIndex == currentWordIndex)
                            Text(wordData.attributedString(highlighted: isHighlighted))
                                .font(wordFont)
                                .captureWordFrame(index: wordData.originalIndex, in: "container")
                                .id(wordData.originalIndex)
                        }
                    }
                }
                Spacer().frame(height: bottomPadding)
            }
        }
        .coordinateSpace(name: "container")
        .onPreferenceChange(WordFrameKey.self) { new in
            setWordFrames(new)
            updateHighlightFrame()
        }
        .onChange(of: currentWordIndex) { _, _ in
            updateHighlightFrame()
        }
    }
    
    // MARK: - Local helpers
    
    // Accessors that unify internal state vs external bindings
    private var wordFrames: [Int: CGRect] {
        get { wordFramesBinding?.wrappedValue ?? _wordFrames }
        nonmutating set {
            if let b = wordFramesBinding {
                b.wrappedValue = newValue
            } else {
                _wordFrames = newValue
            }
        }
    }
    
    private var highlightFrame: CGRect {
        get { highlightFrameBinding?.wrappedValue ?? _highlightFrame }
        nonmutating set {
            if let b = highlightFrameBinding {
                b.wrappedValue = newValue
            } else {
                _highlightFrame = newValue
            }
        }
    }
    
    private func setWordFrames(_ new: [Int: CGRect]) {
        wordFrames = new
    }
    
    private func updateHighlightFrame() {
        if let frame = wordFrames[currentWordIndex] {
            highlightFrame = frame.integral
        } else {
            highlightFrame = .zero
        }
    }
}


// MARK: - Feedback (shared)
public func sendFeedback(word: String, thoughtId: String, chapterNumber: Int) {
    let feedbackValue = bluetoothService.processFeedback(word: word)
    
    feedbackBuffer.addFeedback(
        word: word,
        value: feedbackValue,
        thoughtId: thoughtId,
        chapterNumber: chapterNumber
    )
}
