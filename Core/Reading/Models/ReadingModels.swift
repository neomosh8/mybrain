//struct ChapterData: Equatable, Codable {
//    let chapterNumber: Int
//    let title: String
//    let content: String
//    let status: String
//    let complete: Bool
//
//    enum CodingKeys: String, CodingKey {
//        case chapterNumber = "chapter_number"
//        case title
//        case content
//        case status
//        case complete
//    }
//}

struct ChapterData {
    let number: Int
    let content: String
}

struct ReadingThoughtStatus {
    var thoughtId: String
    var status: String
    var progress: ThoughtProgress
}

struct ChapterProgressState {
    var totalChapters: Int
    var completedChapters: Int
    var currentChapter: Int?
    var isLoading: Bool
}
