struct Thought: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    var description: String?
    let content_type: String
    var cover: String?
    var status: String
    let created_at: String
    let updated_at: String
    let model_3d: String? 
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Thought, rhs: Thought) -> Bool {
        return lhs.id == rhs.id
    }
}
