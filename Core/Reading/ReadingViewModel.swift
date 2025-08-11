import Foundation
import SwiftUICore
import Combine
import NaturalLanguage

@MainActor
class ReadingViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    // Public state for the view
    @Published var paragraphs: [[WordData]] = []
    @Published var currentWordIndex: Int = -1
    @Published var isPlaying = false
    @Published var hasCompletedAllChapters = false
    @Published var isLastChapter = false
    
    // Chapter/UI state
    @Published var chapters: [ChapterTextResponseData] = []
    @Published var displayedChapterCount = 0
    @Published var currentChapterIndex: Int?
    @Published var readingSpeed: Double = 0.3
    @Published var isLoadingChapter = false
    
    // Internal
    private var thoughtId: String = ""
    private var hasRequestedNextChapter = false
    
    // Playback timer
    private var animationTimer: DispatchSourceTimer?
    
    // Index bookkeeping
    private var totalWordCount: Int = 0
    private var indexToWord: [Int: String] = [:]
    private var indexToChapter: [Int: Int] = [:]
    private var chapterRanges: [Int: Range<Int>] = [:]
    
    private var lastFeedbackIndex: Int = -1
    
    // MARK: Lifecycle
    func setup(for thought: Thought) {
        self.thoughtId = thought.id
        setupWebSocketSubscriptions()
        requestNextChapter()
    }
    
    func cleanup() {
        feedbackBuffer.flushBuffer()
        stopTimer()
        cancellables.removeAll()
    }
    
    // MARK: Chapters & WebSocket
    func requestNextChapter() {
        guard !isLoadingChapter else { return }
        isLoadingChapter = true
        hasRequestedNextChapter = false
        
        networkService.webSocket.requestNextChapter(
            thoughtId: thoughtId,
            generateAudio: false
        )
    }
    
    func onChapterHalfway(_ chapterNumber: Int) {
        guard !hasRequestedNextChapter else { return }
        hasRequestedNextChapter = true
        requestNextChapter()
    }
    
    func onChapterFinished(_ chapterNumber: Int) {
        if isLastChapter {
            hasCompletedAllChapters = true
            stopTimer()
            feedbackBuffer.flushBuffer()
        }
    }
    
    private func setupWebSocketSubscriptions() {
        networkService.webSocket.messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message {
        case .chapterText(let status, _, let data):
            if status.isSuccess { handleTextChapterResponse(data: data) }
            isLoadingChapter = false
            
        case .chapterComplete(_, _, let data):
            if let completeData = ChapterCompleteResponseData(from: data),
               let complete = completeData.complete,
               complete {
                isLastChapter = true
            }
            isLoadingChapter = false
            
        default:
            break
        }
    }
    
    private func handleTextChapterResponse(data: [String: Any]?) {
        guard let chapterData = ChapterTextResponseData(from: data),
              let html = chapterData.content else { return }
        
        appendChapter(html: html, chapterNumber: chapterData.chapterNumber ?? (chapters.count + 1))
        chapters.append(chapterData)
        displayedChapterCount = chapters.count
        
        if displayedChapterCount == 1 {
            currentChapterIndex = 0
            isPlaying = true
        }
        
        if isPlaying, animationTimer == nil {
            startTimerIfNeeded()
        }
    }
    
    // MARK: Append pipeline (HTML -> [[WordData]] with global indexing)
    private func appendChapter(html: String, chapterNumber: Int) {
        let (newParagraphs, newIndexMap, wordCount) = parseHTMLToWordData(html: html, startOffset: totalWordCount)
        
        // Append paragraphs (preserve paragraph boundaries)
        if paragraphs.isEmpty {
            paragraphs = newParagraphs
        } else {
            // Merge by appending each incoming paragraph to the model
            paragraphs.append(contentsOf: newParagraphs)
        }
        
        // Update maps
        for (globalIndex, (word, chap)) in newIndexMap {
            indexToWord[globalIndex] = word
            indexToChapter[globalIndex] = chap
        }
        
        // Record range for this chapter
        let start = totalWordCount
        let end = totalWordCount + wordCount
        chapterRanges[chapterNumber] = start..<end
        totalWordCount = end
    }
    
    private func parseHTMLToWordData(html: String, startOffset: Int) -> ([[WordData]], [Int: (String, Int)], Int) {
        // Convert HTML -> AttributedString (fallback to plain text)
        let attributed: AttributedString = {
            guard let data = html.data(using: .utf8) else { return AttributedString(html) }
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            if let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
               let swiftUI = try? AttributedString(ns, including: \.uiKit) {
                return overrideFontFamilyOnly(swiftUI)
            }
            return AttributedString(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }()
        
        // Tokenize into words with NLTagger
        let text = String(attributed.characters)
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        
        var wordRanges: [Range<String.Index>] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType) { _, r in
            let raw = String(text[r])
            let word = raw.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            if word.rangeOfCharacter(from: .letters) != nil {
                wordRanges.append(r)
            }
            return true
        }
        
        // Build [[WordData]] preserving paragraph breaks (\n)
        var result: [[WordData]] = []
        var currentParagraph: [WordData] = []
        var indexMap: [Int: (String, Int)] = [:]
        
        for (i, r) in wordRanges.enumerated() {
            if i > 0 {
                let prev = wordRanges[i - 1]
                let between = text[prev.upperBound..<r.lowerBound]
                if between.contains("\n") {
                    if !currentParagraph.isEmpty { result.append(currentParagraph) }
                    currentParagraph = []
                }
            }
            
            // Attributes for this word
            let attributedRange = Range(r, in: attributed)!
            let substring = AttributedString(attributed[attributedRange])
            let attrs = substring.runs.first?.attributes ?? AttributeContainer()
            let wordText = String(text[r])
            
            // Global index = startOffset + local
            let globalIndex = startOffset + i
            let data = WordData(originalIndex: globalIndex, text: wordText, attributes: attrs)
            currentParagraph.append(data)
            
            // Map for feedback + analytics
            indexMap[globalIndex] = (String(wordText), /* chapterNumber filled by caller */ 0)
        }
        
        if !currentParagraph.isEmpty { result.append(currentParagraph) }
        
        // Caller will rewrite chapter number in indexMap while appending
        return (result, indexMap, wordRanges.count)
    }
    
    private func overrideFontFamilyOnly(_ input: AttributedString) -> AttributedString {
        var content = input
        for run in content.runs {
            let range = run.range
            if let originalFont = run.uiKit.font {
                let size = originalFont.pointSize
                let traits = originalFont.fontDescriptor.symbolicTraits
                var weight: Font.Weight = .regular
                var isItalic = false
                if traits.contains(.traitBold)   { weight = .bold }
                if traits.contains(.traitItalic) { isItalic = true }
                content[range].font = .system(size: size, weight: weight)
                if isItalic {
                    var intents = content[range].inlinePresentationIntent
                    intents?.insert(.emphasized)
                    content[range].inlinePresentationIntent = intents
                }
            }
        }
        return content
    }
    
    // MARK: Playback
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying { startTimerIfNeeded() } else { stopTimer() }
    }
    
    private func startTimerIfNeeded() {
        guard animationTimer == nil else { return }
        guard totalWordCount > 0 else { return }
                
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now() + readingSpeed, repeating: readingSpeed)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in self?.tick() }
        }
        timer.resume()
        animationTimer = timer
    }
    
    private func stopTimer() {
        animationTimer?.cancel()
        animationTimer = nil
    }
    
    private func tick() {
        guard isPlaying, totalWordCount > 0 else { return }
        
        currentWordIndex += 1
        
        if currentWordIndex >= totalWordCount {
            if isLastChapter {
                onChapterFinished(currentChapterIndex ?? (chapters.last?.chapterNumber ?? 0))
            } else {
                stopTimer()
            }

            return
        }
        
        // Emit feedback once per word
        if let word = indexToWord[currentWordIndex] {
            let chapterNum = (currentChapterIndex ?? -1) + 1
            let feedbackValue = bluetoothService.processFeedback(word: word)
            
            feedbackBuffer.addFeedback(
                word: word,
                value: feedbackValue,
                thoughtId: thoughtId,
                chapterNumber: chapterNum
            )
        }
        
        // Halfway trigger / end-of-chapter trigger based on ranges
        if let (chapNum, range) = chapterAndRange(containing: currentWordIndex) {
            let halfway = range.lowerBound + (range.count / 2)
            if currentWordIndex == halfway { onChapterHalfway(chapNum) }
            if currentWordIndex == range.upperBound - 1 {
                if let idx = chapters.firstIndex(where: { ($0.chapterNumber ?? 0) == chapNum }) {
                    currentChapterIndex = min(idx + 1, chapters.count - 1)
                }
            }
        }
    }
    
    private func chapterAndRange(containing index: Int) -> (Int, Range<Int>)? {
        for (chapter, range) in chapterRanges {
            if range.contains(index) { return (chapter, range) }
        }
        return nil
    }
}
