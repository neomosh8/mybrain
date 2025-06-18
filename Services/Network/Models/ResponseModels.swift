import Foundation

// MARK: - Authentication Responses

struct RegisterResponse: Codable {
    let detail: String
}

struct TokenResponse: Codable {
    let access: String
    let refresh: String
    let profileComplete: Bool
    
    enum CodingKeys: String, CodingKey {
        case access = "access"
        case refresh = "refresh"
        case profileComplete = "profile_complete"
    }
}

struct RefreshTokenResponse: Codable {
    let access: String
}

struct LogoutResponse: Codable {
    let detail: String
}

// MARK: - Profile Responses

struct UserProfile: Codable {
    let id: Int?
    let email: String?
    let firstName: String?
    let lastName: String?
    let birthdate: String?
    let gender: String?
    let onboarded: Bool?
    let isActive: Bool?
    let isStaff: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, email, birthdate, gender, onboarded
        case firstName = "first_name"
        case lastName = "last_name"
        case isActive = "is_active"
        case isStaff = "is_staff"
    }
}

struct UserDevice: Codable {
    let deviceName: String
    let osName: String
    let appVersion: String
    let uniqueDeviceId: String
    let createdAt: String
    let lastLogin: String
    
    enum CodingKeys: String, CodingKey {
        case deviceName = "device_name"
        case osName = "os_name"
        case appVersion = "app_version"
        case uniqueDeviceId = "unique_device_id"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
}

struct DeviceTerminationResponse: Codable {
    let detail: String
}

// MARK: - Thought Management Responses

struct ThoughtCreationResponse: Codable {
    let id: Int
    let name: String
    let cover: String?
    let model3d: String?
    let createdAt: String
    let updatedAt: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, cover, status
        case model3d = "model_3d"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Thought: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let contentType: String?
    let cover: String?
    let model3d: String?
    let status: String
    let progress: ThoughtProgress?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, cover, status, progress
        case contentType = "content_type"
        case model3d = "model_3d"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ThoughtProgress: Codable {
    let total: Int
    let completed: Int
    let remaining: Int
}

struct Chapter: Codable {
    let chapterNumber: Int
    let title: String?
    let content: String?
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case title, content, status
        case chapterNumber = "chapter_number"
    }
}

struct ThoughtStatus: Codable {
    let thoughtId: Int
    let thoughtName: String
    let status: String
    let progress: ThoughtProgress?
    let chapters: [Chapter]?
    
    enum CodingKeys: String, CodingKey {
        case status, progress, chapters
        case thoughtId = "thought_id"
        case thoughtName = "thought_name"
    }
}

// MARK: - Thought Operation Responses

struct ThoughtOperationResponse: Codable {
    let status: String
    let message: String
    let data: ThoughtOperationData?
}

struct ThoughtOperationData: Codable {
    let thoughtId: Int?
    let error: String?
    let originalStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case thoughtId = "thought_id"
        case originalStatus = "original_status"
    }
}

struct PassChaptersResponse: Codable {
    let status: String
    let message: String
}

struct SummarizeResponse: Codable {
    let status: String
    let message: String
}

struct ArchiveThoughtResponse: Codable {
    let status: String
    let message: String
}

// MARK: - Analytics Responses

struct ThoughtFeedbacksResponse: Codable {
    let status: String
    let message: String
    let feedbacks: [String: AnyCodable]
    
    private enum CodingKeys: String, CodingKey {
        case status, message, feedbacks
    }
}

struct ThoughtBookmarksResponse: Codable {
    let status: String
    let message: String
    let bookmarks: [String: AnyCodable]
    
    private enum CodingKeys: String, CodingKey {
        case status, message, bookmarks
    }
}

struct RetentionIssuesResponse: Codable {
    let status: String
    let message: String
    let retentions: [String: AnyCodable]
    
    private enum CodingKeys: String, CodingKey {
        case status, message, retentions
    }
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Error Response Models

struct APIErrorResponse: Codable {
    let detail: String?
    let error: String?
    let status: String?
    let message: String?
    
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        detail = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "detail")!)
        error = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "error")!)
        status = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "status")!)
        message = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "message")!)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encodeIfPresent(detail, forKey: DynamicCodingKeys(stringValue: "detail")!)
        try container.encodeIfPresent(error, forKey: DynamicCodingKeys(stringValue: "error")!)
        try container.encodeIfPresent(status, forKey: DynamicCodingKeys(stringValue: "status")!)
        try container.encodeIfPresent(message, forKey: DynamicCodingKeys(stringValue: "message")!)
    }
}

// MARK: - Special Response Handlers

/// For endpoints that return just "ok" string
struct SimpleStringResponse: Codable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Empty Response
struct EmptyResponse: Codable {}

// MARK: - Convenience Extensions

extension ThoughtOperationResponse {
    var isSuccess: Bool {
        status.lowercased() == "success"
    }
    
    var errorMessage: String {
        if isSuccess {
            return message
        } else {
            return data?.error ?? message
        }
    }
}

extension APIErrorResponse {
    var errorMessage: String {
        return detail ?? error ?? message ?? "Unknown error occurred"
    }
}
