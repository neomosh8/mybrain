import SwiftUI
import AVFoundation

struct SubtitleView: View {
    let subtitles: [WordTimestamp]
    let thoughtId: String
    let chapterNumber: Int
    
    @Binding var currentTime: Double
    @State private var currentWordIndex: Int = 0
    @State private var previousWordIndex: Int = -1
    
    // Dependencies
    private let feedbackService: any FeedbackServiceProtocol
    
    // MARK: - Initialization
    init(
        subtitles: [WordTimestamp],
        thoughtId: String,
        chapterNumber: Int,
        currentTime: Binding<Double>,
        feedbackService: any FeedbackServiceProtocol = FeedbackService.shared
    ) {
        self.subtitles = subtitles
        self.thoughtId = thoughtId
        self.chapterNumber = chapterNumber
        self._currentTime = currentTime
        self.feedbackService = feedbackService
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !subtitles.isEmpty {
                // Current subtitle group
                currentSubtitleView
                
                // Progress indicator
                progressIndicator
            } else {
                Text("No subtitles available")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 20)
        .onChange(of: currentTime) { _, newTime in
            updateCurrentWord(for: newTime)
        }
    }
    
    // MARK: - Current Subtitle View
    private var currentSubtitleView: some View {
        VStack(spacing: 8) {
            // Display current word group (3-5 words)
            if let wordGroup = getCurrentWordGroup() {
                HStack(spacing: 4) {
                    ForEach(Array(wordGroup.enumerated()), id: \.offset) { index, wordTimestamp in
                        Text(wordTimestamp.text)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isCurrentWord(wordTimestamp) ? .white : .white.opacity(0.6))
                            .scaleEffect(isCurrentWord(wordTimestamp) ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: currentWordIndex)
                    }
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack {
            Text("Word \(currentWordIndex + 1) of \(subtitles.count)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 4)
        }
        .frame(height: 20)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentWordGroup() -> [WordTimestamp]? {
        guard currentWordIndex < subtitles.count else { return nil }
        
        let groupSize = 4
        let startIndex = max(0, currentWordIndex - 1)
        let endIndex = min(subtitles.count, startIndex + groupSize)
        
        return Array(subtitles[startIndex..<endIndex])
    }
    
    private func isCurrentWord(_ wordTimestamp: WordTimestamp) -> Bool {
        guard currentWordIndex < subtitles.count else { return false }
        return subtitles[currentWordIndex].text == wordTimestamp.text &&
        subtitles[currentWordIndex].start == wordTimestamp.start
    }
    
    private var progress: Double {
        guard !subtitles.isEmpty else { return 0 }
        return Double(currentWordIndex) / Double(subtitles.count)
    }
    
    private func updateCurrentWord(for time: Double) {
        let newIndex = findCurrentWordIndex(for: time)
        
        if newIndex != currentWordIndex && newIndex >= 0 && newIndex < subtitles.count {
            // Send feedback for the previous word when moving to next
            if currentWordIndex >= 0 && currentWordIndex < subtitles.count && currentWordIndex != previousWordIndex {
                sendFeedbackForWord(at: currentWordIndex)
            }
            
            previousWordIndex = currentWordIndex
            currentWordIndex = newIndex
        }
    }
    
    private func findCurrentWordIndex(for time: Double) -> Int {
        for (index, subtitle) in subtitles.enumerated() {
            if time >= subtitle.start && time < subtitle.end {
                return index
            }
        }
        
        // If time is past all subtitles, return the last index
        if time >= subtitles.last?.end ?? 0 {
            return subtitles.count - 1
        }
        
        return currentWordIndex
    }
    
    private func sendFeedbackForWord(at index: Int) {
        guard index >= 0 && index < subtitles.count else { return }
        
        let plainWord = subtitles[index].text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        // Filter out punctuation, whitespace, and very short strings
        guard !plainWord.isEmpty,
              plainWord.count > 1,
              containsAlphanumeric(plainWord) else { return }
        
        // Submit feedback using the service
        feedbackService.submitFeedbackSync(
            thoughtId: thoughtId,
            chapterNumber: chapterNumber,
            word: plainWord
        )
        
        print("Feedback submitted for word: \(plainWord)")
    }
    
    // Helper function to check if string contains alphanumeric characters
    private func containsAlphanumeric(_ string: String) -> Bool {
        return string.rangeOfCharacter(from: CharacterSet.alphanumerics) != nil
    }
}

// MARK: - WordTimestamp Model
//struct WordTimestamp {
//    let text: String
//    let start: Double
//    let end: Double
//}

struct WordTimestamp: Identifiable {
    let id = UUID()
    let start: Double
    let end: Double
    let text: String
}
