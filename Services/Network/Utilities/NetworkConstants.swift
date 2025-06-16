import Foundation

struct NetworkConstants {
    static let baseURL = "https://brain.sorenapp.ir"
    static let webSocketBaseURL = "wss://brain.sorenapp.ir"
    static var userTimezone: String {
        TimeZone.current.identifier
    }
    
    // API Paths
    struct Paths {
        static let authRequest = "/api/v1/profiles/auth/request/"
        static let authVerify = "/api/v1/profiles/auth/verify/"
        static let tokenRefresh = "/api/v1/profiles/token/refresh/"
        static let googleLogin = "/api/v1/profiles/google-login/"
        static let appleLogin = "/api/v1/profiles/apple-login/"
        static let logout = "/api/v1/profiles/logout/"
        static let profile = "/api/v1/profiles/profile/"
        static let updateProfile = "/api/v1/profiles/profile/update/"
        static let devices = "/api/v1/profiles/devices/"
        static let deviceLogout = "/api/v1/profiles/devices/logout/"
        static let entertainmentTypes = "/api/v1/profiles/entertainment/types/"
        static let entertainmentGenres = "/api/v1/profiles/entertainment/genres/"
        static let entertainmentContexts = "/api/v1/profiles/entertainment/contexts/"
        static let entertainmentOptions = "/api/v1/profiles/entertainment/options/"
        static let thoughts = "/api/v1/thoughts/"
        static let createThought = "/api/v1/thoughts/create/"
        
        static func thoughtDetail(_ id: Int) -> String { "/api/v1/thoughts/\(id)/" }
        static func resetThought(_ id: Int) -> String { "/api/v1/thoughts/\(id)/reset/" }
        static func retryThought(_ id: Int) -> String { "/api/v1/thoughts/\(id)/retry/" }
        static func passChapters(_ id: Int) -> String { "/api/v1/thoughts/\(id)/pass/" }
        static func summarizeThought(_ id: Int) -> String { "/api/v1/thoughts/\(id)/summarize/" }
        static func deleteThought(_ id: Int) -> String { "/api/v1/thoughts/\(id)/delete/" }
        static func thoughtFeedbacks(_ id: Int) -> String { "/api/v1/thoughts/\(id)/feedbacks/" }
        static func thoughtBookmarks(_ id: Int) -> String { "/api/v1/thoughts/\(id)/bookmarks/" }
        static func thoughtRetentions(_ id: Int) -> String { "/api/v1/thoughts/\(id)/retentions/" }
    }
}
