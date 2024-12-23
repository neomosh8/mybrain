import SwiftUI
import AVKit
import Combine

struct StreamThoughtView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel
    @State private var player: AVPlayer?
    @State private var playerError: Error?
    @State private var isFetchingLinks: Bool = false
    @State private var masterPlaylistURL: URL?
    @State private var nextChapterRequested = false
    @State private var playerItemObservation: AnyCancellable?
    @State private var playbackProgressObserver: Any?
    @State private var currentChapterNumber: Int = 1
    @State private var showRestartOptions = false
    @State private var thoughtStatus: ThoughtStatus?
    @State private var showResetSuccess = false
    @State private var resetCompleted = false
    @State private var lastCheckTime: Double = 0.0
    @State private var startTime: Date?
    @State private var currentSubtitles: AttributedString = AttributedString("")
    @State private var isPlaying = false
    @State private var subtitleSegments: [SubtitleSegment] = []
    @State private var currentSubtitleSegment: SubtitleSegment?

    var body: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            VStack {
                if isFetchingLinks {
                    ProgressView("Fetching Streaming Links...")
                } else if let player = player {
                    if thought.content_type == "audio" {
                         audioPlayerControls
                      } else {
                          VideoPlayer(player: player)
                             .frame(minHeight: 200)
                      }
                    
                    if !currentSubtitles.characters.isEmpty {
                         subtitleView
                     }
                } else if let error = playerError {
                    Text("Player Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                } else {
                    Text("Ready to Stream \(thought.name)")
                        .foregroundColor(.black)
                }
            }
            .padding()
            
            if showRestartOptions {
                restartOptionsAlert
            }
        }
        .alert(isPresented: $showResetSuccess) {
            Alert(title: Text("Success"), message: Text("Reading progress reset successfully"), dismissButton: .default(Text("Ok")))
        }
        .onAppear {
            fetchThoughtStatus()
        }
        .onDisappear {
            player?.pause()
            player = nil
            masterPlaylistURL = nil
            playerItemObservation?.cancel()
            if let observer = playbackProgressObserver {
              player?.removeTimeObserver(observer)
            }
            playbackProgressObserver = nil
           
        }
    }
    
   private var audioPlayerControls: some View {
       HStack {
           Button(action: {
                if isPlaying {
                    player?.pause()
                } else {
                   player?.play()
                }
                isPlaying.toggle()
           }) {
               Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                   .font(.system(size: 40))
                   .foregroundColor(.white)
           }
       }
    }

    private var subtitleView: some View {
          Text(currentSubtitles)
               .font(.system(size: 20, weight: .semibold))
               .foregroundColor(.white)
               .padding(10)
               .background(Color.black.opacity(0.7))
             .cornerRadius(10)
            .padding()
    }
    
    func fetchThoughtStatus() {
        socketViewModel.sendMessage(action: "thought_status", data: ["thought_id": thought.id])
          
          socketViewModel.$incomingMessage
                .compactMap { $0 }
                .filter { $0["type"] as? String == "thought_chapters" }
                .first()
                .sink { message in
                    DispatchQueue.main.async {
                        self.handleThoughtStatusResponse(message: message)
                    }
                }
                .store(in: &socketViewModel.cancellables)
    }

    func handleThoughtStatusResponse(message: [String: Any]) {
        guard let status = message["status"] as? String,
              status == "success",
              let data = message["data"] as? [String: Any],
              let thoughtId = data["thought_id"] as? Int,
              let thoughtName = data["thought_name"] as? String,
              let statusType = data["status"] as? String,
              let progressData = data["progress"] as? [String: Any],
             let chaptersData = data["chapters"] as? [[String: Any]]
             else {
            print("Invalid thought status response \(message)")
            return
        }
        
        
        let progress = ProgressData(
              total: progressData["total"] as? Int ?? 0,
              completed: progressData["completed"] as? Int ?? 0,
              remaining: progressData["remaining"] as? Int ?? 0
          )
        
        var chapters: [ChapterDataModel] = []
        for chapterData in chaptersData {
            let chapter = ChapterDataModel(
                  chapter_number: chapterData["chapter_number"] as? Int ?? 0,
                  title: chapterData["title"] as? String ?? "",
                  content: chapterData["content"] as? String ?? "",
                  status: chapterData["status"] as? String ?? ""
              )
           chapters.append(chapter)
        }


        let statusModel =  ThoughtStatus(
            thought_id: thoughtId,
            thought_name: thoughtName,
            status: statusType,
            progress: progress,
            chapters: chapters
          )
          
          self.thoughtStatus = statusModel
        
        if statusType == "in_progress" {
            showRestartOptions = true
        } else if statusType == "finished" {
            showRestartOptions = true
        } else {
            fetchStreamingLinks()
        }
    }
    
    var restartOptionsAlert: some View {
        VStack {
           
            if thoughtStatus?.status == "in_progress" {
                Text("It seems you are in middle of the stream for \(thought.name).")
                     .font(.headline)
                     .padding()
                   
                    HStack {
                        Button("Restart From Beginning") {
                           resetReading()
                         }
                       .buttonStyle(.borderedProminent)
                        
                         Button("Resume") {
                             showRestartOptions = false
                             fetchStreamingLinks()
                          }
                        .buttonStyle(.bordered)
                     }
                
            } else {
                   Text("It seems you have finished the stream for \(thought.name).")
                        .font(.headline)
                        .padding()

                Button("Restart From Beginning") {
                     resetReading()
                 }
                  .buttonStyle(.borderedProminent)
             }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }

   func resetReading() {
       resetCompleted = false
        socketViewModel.sendMessage(action: "reset_reading", data: ["thought_id": thought.id])
        
        socketViewModel.$incomingMessage
             .compactMap { $0 }
             .filter { $0["type"] as? String == "reset_response" }
             .first()
             .sink { message in
                 DispatchQueue.main.async {
                     self.handleResetResponse(message: message)
                 }
             }
             .store(in: &socketViewModel.cancellables)
    }
    
   func handleResetResponse(message: [String: Any]) {
        guard let status = message["status"] as? String,
              status == "success" else {
            print("reset reading was unsuccesfull")
            return
        }
       
       showResetSuccess = true
       showRestartOptions = false
       resetCompleted = true
       fetchStreamingLinks()
   }
    
    func fetchStreamingLinks() {
         isFetchingLinks = true
        socketViewModel.sendMessage(action: "streaming_links", data: ["thought_id": thought.id])
        
        // Observe incoming messages for the streaming links response
        socketViewModel.$incomingMessage
            .compactMap { $0 } // Remove nil values
            .filter { $0["type"] as? String == "streaming_links" }
            .first() // Take only the first matching message
            .sink { message in
                DispatchQueue.main.async {
                    self.handleStreamingLinksResponse(message: message)
                }
            }
            .store(in: &socketViewModel.cancellables)
    }
    
   func handleStreamingLinksResponse(message: [String: Any]) {
         isFetchingLinks = false // stop showing loading
          guard let status = message["status"] as? String,
                  status == "success",
                let data = message["data"] as? [String: Any],
                let masterPlaylistPath = data["master_playlist"] as? String,
                let subtitlesPlaylistPath = data["subtitles_playlist"] as? String? else {
                
              let errorMessage = message["message"] as? String ?? "Failed to get the streaming urls"
              print("Failed to get streaming links: \(errorMessage)")
              playerError = NSError(domain: "StreamingError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
              return
          }
          
      
         // Assuming the base URL is the same as the websocket connection (you may need to configure this differently)
        let baseURL = "https://\(socketViewModel.baseUrl)" // Assuming https since you are providing absolute urls from server.
          guard let url = URL(string: baseURL + masterPlaylistPath) else {
                 playerError = NSError(domain: "StreamingError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL provided: \(baseURL + masterPlaylistPath)"])
                  return
           }
           self.masterPlaylistURL = url
         
         if let subtitlePath = subtitlesPlaylistPath, !subtitlePath.isEmpty {
            let subtitleUrl = URL(string: baseURL + subtitlePath)
            print("fetchSubtitles: URL \(String(describing: subtitleUrl))")
            fetchSubtitles(url: subtitleUrl, baseUrl: baseURL)
        } else {
             currentSubtitles = AttributedString("")
       }
           
           self.setupPlayer(url: url)
       }
    
   func setupPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        startTime = Date()
        isPlaying = true
        
        if playerItemObservation == nil {
           playerItemObservation = player?.publisher(for: \.currentItem?.status)
                .compactMap{ $0 }
                .sink { status in
                  print("player item status changed \(status)")
                    if status == .readyToPlay {
                       startPlaybackProgressObservation()
                    }
                 }
         }
    }
    
  func startPlaybackProgressObservation() {
       guard let player = player else {
            print("startPlaybackProgressObservation: player is nil")
            return
        }

      let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
      print("startPlaybackProgressObservation: adding time observer")
        playbackProgressObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {  time in
          print("time observer called with \(time.seconds)")
           self.checkPlaybackProgress(currentTime: time.seconds)
       }
    }
    
  func checkPlaybackProgress(currentTime: Double) {
       guard let player = player else {
            print("checkPlaybackProgress: player is nil")
            return
        }
  
     if let start = startTime, !nextChapterRequested {
            let timeInterval = Date().timeIntervalSince(start)
            if (timeInterval > 10 && currentTime != lastCheckTime) ||
               (timeInterval > 30)  {
                  print("checkPlaybackProgress: requesting next chapter based on time, currentTime: \(currentTime) lastCheckTime: \(lastCheckTime)")
                  nextChapterRequested = true
                    lastCheckTime = currentTime
                  requestNextChapter()
            }
       }
        
        updateSubtitle(time: currentTime)
   }
    
  func requestNextChapter() {
        print("request next chapter with thought id: \(thought.id), current chapter is \(currentChapterNumber)")
       let data: [String: Any] = ["thought_id": thought.id, "generate_audio": true]

        print("Sending next_chapter message: \(data)")
        socketViewModel.sendMessage(action: "next_chapter", data: data)

        // Observe for chapter updates
       socketViewModel.$incomingMessage
            .compactMap { $0 } // Remove nil values
           .filter {
               guard let type = $0["type"] as? String,
                     type == "chapter_response",
                     let data = $0["data"] as? [String: Any],
                     let status = data["status"] as? String else { return false }
               return status == "reading" || status == "complete"
           }

           .first() // Take only the first matching message
           .sink { message in
               DispatchQueue.main.async {
                 handleNextChapterResponse(message: message)
               }
           }
           .store(in: &socketViewModel.cancellables)
   }
    
    func handleNextChapterResponse(message: [String: Any]) {
        print("next chapter available updating the playlist url")
       
        guard let data = message["data"] as? [String: Any],
              let newChapterNumber = data["chapter_number"] as? Int,
             let status = data["status"] as? String else {
            print("Invalid chapter response \(message)")
            return
       }
        
       currentChapterNumber = newChapterNumber
       nextChapterRequested = false
        
       if status == "reading" {
           print("new chapter generated, wait for complete signal")
           return
        } else if status == "complete" {
           print("New chapter is complete, updating player")
           if let masterPlaylistURL = masterPlaylistURL {
               setupPlayer(url: masterPlaylistURL)
           } else {
             fetchStreamingLinks()
           }
           
           if let currentTime = player?.currentTime().seconds {
               updateSubtitle(time: currentTime)
         }
        }
   }
    
  func fetchSubtitles(url: URL?, baseUrl: String) {
        guard let url = url else {
               currentSubtitles = AttributedString("")
               return
         }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching subtitles: \(error)")
                DispatchQueue.main.async {
                   self.currentSubtitles = AttributedString("Error loading subtitles")
                }
               return
           }
           
             //check if response is a 404
          if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
              print("Error fetching subtitles, 404 returned")
                DispatchQueue.main.async {
                   self.currentSubtitles = AttributedString("")
                 }
                return
            }
          
            guard let data = data, let subtitleString = String(data: data, encoding: .utf8) else {
              print("No subtitle data or invalid encoding")
                DispatchQueue.main.async {
                   self.currentSubtitles = AttributedString("")
                }
               return
          }
            
          DispatchQueue.main.async {
               self.parseSubtitles(subtitleString: subtitleString, baseUrl: baseUrl)
           }
       }.resume()
   }

    private func parseSubtitles(subtitleString: String, baseUrl: String) {
         let lines = subtitleString.components(separatedBy: "\n")
        
        if lines.count > 1 {
           var subtitleURL : String? = nil
            for line in lines {
               if !line.hasPrefix("#") && !line.isEmpty {
                  subtitleURL = line
                    break;
                }
          }
            
            if let subtitleUrlString = subtitleURL {
                if let subtitleUrl = URL(string: baseUrl + "/api/v1/thoughts/\(thought.id)/stream/" + subtitleUrlString) {
                   print("Fetching vtt content \(String(describing: subtitleUrl))")
                   fetchVTTSubtitleContent(url: subtitleUrl)
                } else {
                    //if subtitle is not a url, then display it directly
                   let subtitleLines = lines.filter { line in
                        return !line.hasPrefix("#") && !line.isEmpty
                    }
                       self.currentSubtitles = AttributedString(subtitleLines.joined(separator: "\n"))
                 }
           } else {
              self.currentSubtitles = AttributedString("")
          }
           
       } else {
         self.currentSubtitles = AttributedString("")
       }
    }
    
    
   func fetchVTTSubtitleContent(url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
           if let error = error {
                print("Error fetching VTT subtitles: \(error)")
                DispatchQueue.main.async {
                   self.currentSubtitles = AttributedString("Error loading subtitles")
                 }
               return
           }
            
           guard let data = data, let subtitleString = String(data: data, encoding: .utf8) else {
               print("No VTT subtitle data or invalid encoding")
               DispatchQueue.main.async {
                    self.currentSubtitles = AttributedString("")
                  }
                return
           }
            
         DispatchQueue.main.async {
              self.subtitleSegments = self.parseVTT(vttString: subtitleString)
                self.currentSubtitles = self.attributedTextForTime(time: 0)
          }
        }.resume()
   }
    
   func parseVTT(vttString: String) -> [SubtitleSegment] {
        var segments: [SubtitleSegment] = []
       let lines = vttString.components(separatedBy: "\n")
        var currentSegment: SubtitleSegment? = nil

      for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("NOTE") {
               continue // Skip comments
            } else if trimmedLine.contains("-->") {
                if let segment = currentSegment {
                   segments.append(segment)
                }
                
                let parts = trimmedLine.components(separatedBy: " --> ")
               guard parts.count == 2 else {
                 print("Invalid timestamp format: \(trimmedLine)")
                    continue
              }

              let startTime = parseTime(parts[0])
             let endTime = parseTime(parts[1])
               currentSegment = SubtitleSegment(startTime: startTime, endTime: endTime, text: "")
            } else if !trimmedLine.isEmpty  && !trimmedLine.hasPrefix("WEBVTT"){
              currentSegment?.text += trimmedLine + " "
          }
       }
        
        if let segment = currentSegment {
           segments.append(segment)
        }
         return segments
   }
  
    func parseTime(_ timeString: String) -> Double {
         let parts = timeString.components(separatedBy: ":")
         guard parts.count == 3,
               let hours = Double(parts[0]),
               let minutes = Double(parts[1]),
             let secondsWithFraction = Double(parts[2]) else {
             print("invalid time \(timeString)")
             return 0
       }
   
       return hours * 3600 + minutes * 60 + secondsWithFraction
   }
    
  private func updateSubtitle(time: Double) {
       var foundSegment : SubtitleSegment? = nil
       for segment in subtitleSegments {
            if time >= segment.startTime && time <= segment.endTime {
                foundSegment = segment
               break;
            }
       }
        
        if let segment = foundSegment  {
           currentSubtitleSegment = foundSegment
          currentSubtitles = attributedTextForTime(time: time, currentSegment: segment)
       }
   }
    
  func attributedTextForTime(time: Double, currentSegment: SubtitleSegment? = nil ) -> AttributedString {
         guard let currentSegment = currentSegment  else {
            print("attributedTextForTime: currentSegment is nil")
             return  AttributedString("")
        }
        
        var attributedString = AttributedString(currentSegment.text)
        
       let words = currentSegment.text.split(separator: " ")
       var runningLength = 0
      
        for word in words {
             let wordString = String(word)
            let wordStartTime = currentSegment.startTime + calculateWordStartTime(text: String(currentSegment.text), word: wordString, currentTime: time)
             print("attributedTextForTime: time \(time) wordStartTime \(wordStartTime)  ")
            if time >= wordStartTime && time <= currentSegment.endTime {
                
               if let range = attributedString.range(of: wordString, options: .caseInsensitive) {
                   var temp = attributedString[range]
                  temp.foregroundColor = Color.yellow
                attributedString.replaceSubrange(range, with: temp)
              }
          }
             runningLength += wordString.count + 1
      }
      print("attributedTextForTime: created string \(attributedString)")
        return attributedString
    }
    
   func calculateWordStartTime(text: String, word: String, currentTime: Double ) -> Double{
        let words = text.split(separator: " ")
          
      var wordStartTime = 0.0
      var currentLength = 0.0
        for w in words {
            if String(w) == word {
                break;
            }
            wordStartTime +=  Double(String(w).count + 1 ) * 0.02
        }
        
       print("calculateWordStartTime: word \(word) wordStartTime \(wordStartTime) ")
        return wordStartTime
   }
}

// MARK: - Helper Models
struct ThoughtStatus {
    let thought_id: Int
    let thought_name: String
    let status: String
    let progress: ProgressData
    let chapters: [ChapterDataModel]
}

struct ProgressData {
    let total: Int
    let completed: Int
    let remaining: Int
}

struct ChapterDataModel {
    let chapter_number: Int
    let title: String
    let content: String
    let status: String
}

struct SubtitleSegment: Equatable {
    let startTime: Double
    let endTime: Double
    var text: String
}
