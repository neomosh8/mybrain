struct Thought: Codable, Identifiable {
    let id: Int
    let name: String
    var description: String?
    let content_type: String
    var cover: String?
    var status: String  // Changed from let to var
    let created_at: String
    let updated_at: String
}
