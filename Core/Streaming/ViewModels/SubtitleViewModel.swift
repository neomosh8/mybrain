//SubtitleViewModel.swift
import SwiftUI
import Combine

/// ViewModel that holds an array of .vtt segments, the current active segment,
/// and logic to highlight the current word based on playback time.
class SubtitleViewModel: ObservableObject {
    @Published var segments: [SubtitleSegmentLink] = []
    @Published var currentSegment: SubtitleSegmentData?
    @Published var currentSegmentIndex: Int = 0
    
    /// We'll track the global player time directly.
    @Published var currentGlobalTime: Double = 0
    
    // load the .vtt file at a given index, parse it, and set `currentSegment`.
    func loadSegment(at index: Int) {
        guard index >= 0, index < segments.count else {
            print("🎵 loadSegment => index \(index) out of range (total: \(segments.count))")
            return
        }
        currentSegmentIndex = index
        
        let link = segments[index]
        print("🎵 Loading segment \(index): \(link.urlString)")
        fetchAndParseVTT(from: link.urlString) { [weak self] segmentData in
            DispatchQueue.main.async {
                print("🎵 Loaded segment with \(segmentData.words.count) words")
                if segmentData.words.count > 0 {
                    print("🎵 First few words: \(Array(segmentData.words.prefix(5)).map { $0.text })")
                }
                self?.currentSegment = segmentData
            }
        }
    }

    /// Directly store the player's global time.
    func updateCurrentTime(_ globalPlayerTime: Double) {
        self.currentGlobalTime = globalPlayerTime
    }
    
    /// If you want to auto-switch segments once we pass the last cue of the current segment:
    /// We can see if the global time surpasses the maxEnd of the currentSegment,
    /// then load the next segment. But only if each .vtt truly ends and the next .vtt picks up later.
    func checkSegmentBoundary(onNextSegment: (Int) -> Void) {
        guard !segments.isEmpty else { return }
        
        // Figure out which segment truly matches the current global time
        if let newIndex = findSegmentIndex(for: currentGlobalTime),
           newIndex != currentSegmentIndex {
            onNextSegment(newIndex)  // Tells the caller: "Load segment at newIndex"
        }
    }
    
    /// Finds the segment whose [minStart, maxEnd) range contains `time`.
    /// If none match exactly, returns nil or the last if you want a fallback.
    private func findSegmentIndex(for time: Double) -> Int? {
        for (i, seg) in segments.enumerated() {
            if time >= seg.minStart && time < seg.maxEnd {
                return i
            }
        }
        // If time goes beyond the last segment’s maxEnd, you can decide:
        // return segments.count - 1 to stick on the last segment
        return nil
    }
    
    
    /// Download and parse the .vtt file
    private func fetchAndParseVTT(from urlString: String, completion: @escaping (SubtitleSegmentData) -> Void) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let e = error {
                print("fetchAndParseVTT => error: \(e.localizedDescription)")
                return
            }
            guard let data = data,
                  let content = String(data: data, encoding: .utf8)
            else {
                print("fetchAndParseVTT => invalid data")
                return
            }
            let parsed = self.parseVTT(content: content)
            completion(parsed)
        }.resume()
    }
    
    /// Very naive .vtt parser that lumps all text lines into one paragraph
    /// and sets each line's start/end time. Then we break it into words.
    private func parseVTT(content: String) -> SubtitleSegmentData {
        var words: [WordTimestamp] = []
        var paragraphBuilder = ""
        
        let lines = content.components(separatedBy: .newlines)
        let timeRegex = try! NSRegularExpression(
            pattern: #"(\d+):(\d+):(\d+\.\d+)\s-->\s(\d+):(\d+):(\d+\.\d+)"#,
            options: []
        )
        
        for i in 0..<lines.count {
            let line = lines[i]
            if let match = timeRegex.firstMatch(
                in: line,
                options: [],
                range: NSRange(location: 0, length: line.utf16.count)) {
                
                guard let startTime = parseTime(from: line, match: match, isStart: true),
                      let endTime   = parseTime(from: line, match: match, isStart: false)
                else { continue }
                
                // Next line(s) are the text
                var j = i + 1
                var cueTextLines: [String] = []
                while j < lines.count,
                      !lines[j].isEmpty,
                      timeRegex.firstMatch(in: lines[j],
                                           options: [],
                                           range: NSRange(location: 0, length: lines[j].utf16.count)) == nil {
                    cueTextLines.append(lines[j])
                    j += 1
                }
                
                let combinedCueText = cueTextLines.joined(separator: " ")
                paragraphBuilder.append(combinedCueText + " ")
                
                let splitted = combinedCueText
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                for w in splitted {
                    words.append(WordTimestamp(start: startTime, end: endTime, text: w))
                }
            }
        }
        
        let allStarts = words.map(\.start)
        let allEnds   = words.map(\.end)
        let minStart = allStarts.min() ?? 0
        let maxEnd   = allEnds.max()   ?? 0
        
        return SubtitleSegmentData(
            paragraph: paragraphBuilder.trimmingCharacters(in: .whitespacesAndNewlines),
            words: words.sorted { $0.start < $1.start },
            minStart: minStart,
            maxEnd:   maxEnd
        )
    }
    
    private func parseTime(from line: String,
                           match: NSTextCheckingResult,
                           isStart: Bool) -> Double? {
        let hourIndex   = isStart ? 1 : 4
        let minuteIndex = isStart ? 2 : 5
        let secondIndex = isStart ? 3 : 6
        
        func groupString(_ idx: Int) -> String {
            let range = match.range(at: idx)
            return (line as NSString).substring(with: range)
        }
        
        guard let hh = Double(groupString(hourIndex)),
              let mm = Double(groupString(minuteIndex)),
              let ss = Double(groupString(secondIndex))
        else { return nil }
        
        return hh * 3600 + mm * 60 + ss
    }
}
