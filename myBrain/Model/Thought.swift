struct Thought: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let content_type: String
    let cover: String?
    let status: String
    let created_at: String
    let updated_at: String
}
