import SwiftUI
import Combine

struct Paragraph {
    let chapterNumber: Int
    let content: String
}

struct ThoughtDetailView: View {
    let thought: Thought
    @ObservedObject var socketViewModel: WebSocketViewModel
    
    @State private var paragraphs: [Paragraph] = []
    @State private var displayedParagraphsCount = 0
    @State private var scrollProxy: ScrollViewProxy?
    
    @State private var currentChapterIndex: Int?
    @State private var wordInterval: Double = 0.15
    @State private var sliderPosition: CGPoint = CGPoint(x: 100, y: 200)
    
    // Flags to handle final chapter
    @State private var hasCompletedAllChapters = false
    @State private var lastChapterComplete = false
    
    @State private var showResetConfirmation: Bool = false
    @State private var thoughtStatus: String = "not_started"
    @State private var progressData: ProgressData?

    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""


    var body: some View {
        ZStack {
            // E-ink background
            Color("EInkBackground")
                .ignoresSafeArea()
            
            if hasCompletedAllChapters {
                // Once we confirm the final animation has finished,
                // show the completion screen
                ChapterCompletionView(socketViewModel: socketViewModel,
                                      thoughtId: thought.id)
                
            } else {
                // Show progress if no paragraphs yet
                if displayedParagraphsCount == 0 {
                    ProgressView("Loading First Chapter...")
                        .tint(.gray)
                        .foregroundColor(.black)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                        )
                    
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 1) {
                                ForEach(0..<displayedParagraphsCount, id: \.self) { index in
                                    AnimatedParagraphView(
                                        paragraph: paragraphs[index].content,
                                        backgroundColor: Color("ParagraphBackground"),
                                        wordInterval: wordInterval,
                                        chapterIndex: index,
                                        thoughtId: thought.id,
                                        chapterNumber: paragraphs[index].chapterNumber,
                                        socketViewModel: socketViewModel,
                                        onHalfway: {
                                            // Request next chapter at halfway
                                            if index >= 0 {
                                                requestNextChapter()
                                            }
                                        },
                                        onFinished: {
                                            // Once this chapter’s animation finishes
                                            let nextIndex = index + 1
                                            // If there's a next paragraph, move forward
                                            if displayedParagraphsCount > nextIndex {
                                                currentChapterIndex = nextIndex
                                            } else {
                                                // No more paragraphs in memory
                                                // If the server indicated "no more chapters," show completion
                                                if lastChapterComplete {
                                                    hasCompletedAllChapters = true
                                                }
                                            }
                                        },
                                        currentChapterIndex: $currentChapterIndex
                                    )
                                    .id(index)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 16)
                            .onAppear {
                                self.scrollProxy = proxy
                            }
                        }
                    }
                    // The speed slider
                    sliderContainer
                        .position(sliderPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    self.sliderPosition = value.location
                                }
                        )
                }
            }
        }
        .navigationTitle("Thought Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Request the first chapter
            requestThoughtStatus()
        }
        .onDisappear {
            // Cancel ongoing processes
            socketViewModel.clearChapterData()
            paragraphs = []
            displayedParagraphsCount = 0
            currentChapterIndex = nil
        }
        // Observe when new chapter data arrives
        .onReceive(socketViewModel.$chapterData) { chapterData in
            guard let chapterData = chapterData else { return }
            
            if chapterData.complete {
                // The server indicated "no more chapters"
                lastChapterComplete = true
                
                // If the server provided final text, optionally show it:
                // (If you want a "final chapter" to read, append it here)
                if !chapterData.content.isEmpty && chapterData.content != "No content" {
                    paragraphs.append(Paragraph(chapterNumber: chapterData.chapterNumber,
                                                content: chapterData.content))
                    displayedParagraphsCount = paragraphs.count
                    if displayedParagraphsCount == 1 {
                        currentChapterIndex = 0
                    }
                }
                
            } else {
                // Normal chapter
                paragraphs.append(Paragraph(
                    chapterNumber: chapterData.chapterNumber,
                    content: chapterData.content
                ))
                displayedParagraphsCount = paragraphs.count
                
                // If this is the first chapter
                if displayedParagraphsCount == 1 {
                    currentChapterIndex = 0
                }
            }
        }
        // handle reset response
        .onReceive(socketViewModel.$incomingMessage) { incomingMessage in
            guard let incomingMessage = incomingMessage else { return }
            if let type = incomingMessage["type"] as? String, type == "reset_response"{
                 if let status = incomingMessage["status"] as? String, status == "success" {
                       showAlert(title: "Success", message: "Reading progress and streaming content have been reset")
                       resetView()
                 }
            }
            
        }
        // handle thought_status response
        .onReceive(socketViewModel.$incomingMessage) { incomingMessage in
             guard let incomingMessage = incomingMessage else { return }
            if let type = incomingMessage["type"] as? String, type == "thought_chapters" {
                if let data = incomingMessage["data"] as? [String: Any] {
                    self.thoughtStatus = data["status"] as? String ?? "not_started"
                    if let progress = data["progress"] as? [String: Any] {
                        self.progressData = ProgressData(
                            total: progress["total"] as? Int ?? 0,
                            completed: progress["completed"] as? Int ?? 0,
                            remaining: progress["remaining"] as? Int ?? 0
                        )
                    }
                     self.showResetConfirmation = true
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("What do you want to do?", isPresented: $showResetConfirmation, actions: {
            if thoughtStatus == "in_progress" {
                Button("Re-start from beginning") {
                    resetReading()
                    
                }
                Button("Resume") {
                    requestNextChapter()
                    
                }
            } else if thoughtStatus == "finished" {
                Button("Performance summary") {
                    hasCompletedAllChapters = true
                }
                Button("Restart from beginning") {
                    resetReading()
                }
            }
        })
        
    }
    
    private var sliderContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 60, height: 200)
                .shadow(radius: 5)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack {
                Image(systemName: "tortoise")
                    .font(.caption)
                    .offset(y: -5)
                
                Slider(value: $wordInterval, in: 0.01...0.25)
                    .frame(height: 120)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: 0.5, y: 0.5)
                    .clipped()
                
                Image(systemName: "hare")
                    .font(.caption)
                    .offset(y: 5)
            }
            .padding(.vertical, 1)
        }
    }
    
    private func requestNextChapter() {
        let messageData: [String: Any] = [
            "thought_id": thought.id,
            "generate_audio": false
        ]
        socketViewModel.sendMessage(action: "next_chapter", data: messageData)
    }
    private func requestThoughtStatus() {
        let messageData: [String: Any] = [
             "thought_id": thought.id
        ]
        socketViewModel.sendMessage(action: "thought_status", data: messageData)
        
    }

    private func resetReading() {
        let messageData: [String: Any] = [
            "thought_id": thought.id
        ]
        socketViewModel.sendMessage(action: "reset_reading", data: messageData)
        
    }
    
    
    private func resetView(){
        paragraphs = []
        displayedParagraphsCount = 0
        currentChapterIndex = nil
        hasCompletedAllChapters = false
        lastChapterComplete = false
        requestNextChapter()

    }

    private func showAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.showAlert = true
    }
}

