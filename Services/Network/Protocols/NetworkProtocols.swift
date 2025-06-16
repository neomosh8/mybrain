import Foundation
import Combine

// MARK: - Core Protocols

protocol HTTPNetworkServiceProtocol: AuthenticationAPI, ProfileAPI, ThoughtsAPI, EntertainmentAPI {}

protocol AuthenticationAPI {
    func requestAuthCode(email: String) -> AnyPublisher<NetworkResult<RegisterResponse>, Never>
    func verifyAuthCode(email: String, code: String, deviceInfo: DeviceInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func refreshToken(refreshToken: String) -> AnyPublisher<NetworkResult<RefreshTokenResponse>, Never>
    func googleLogin(idToken: String, deviceInfo: DeviceInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func appleLogin(userId: String, firstName: String?, lastName: String?, email: String?, deviceInfo: DeviceInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func logout(refreshToken: String, deviceId: String) -> AnyPublisher<NetworkResult<LogoutResponse>, Never>
}

protocol ProfileAPI {
    func getProfile() -> AnyPublisher<NetworkResult<UserProfile>, Never>
    func updateProfile(firstName: String?, lastName: String?, birthdate: String?, gender: String?) -> AnyPublisher<NetworkResult<SimpleStringResponse>, Never>
    func updatePreferences(types: [PreferenceItem]?, genres: [PreferenceItem]?, contexts: [PreferenceItem]?) -> AnyPublisher<NetworkResult<SimpleStringResponse>, Never>
    func listDevices() -> AnyPublisher<NetworkResult<[UserDevice]>, Never>
    func terminateDevice(deviceId: String, currentDeviceId: String) -> AnyPublisher<NetworkResult<DeviceTerminationResponse>, Never>
}

protocol ThoughtsAPI {
    func createThoughtFromURL(url: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func createThoughtFromText(text: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func createThoughtFromPodcast(url: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func createThoughtFromFile(fileData: Data, contentType: String, fileName: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func getAllThoughts() -> AnyPublisher<NetworkResult<[Thought]>, Never>
    func getThoughtStatus(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtStatus>, Never>
    func resetThoughtProgress(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never>
    func retryFailedThought(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never>
    func passChapters(thoughtId: Int, upToChapter: Int) -> AnyPublisher<NetworkResult<PassChaptersResponse>, Never>
    func summarizeChapters(thoughtId: Int) -> AnyPublisher<NetworkResult<SummarizeResponse>, Never>
    func archiveThought(thoughtId: Int) -> AnyPublisher<NetworkResult<ArchiveThoughtResponse>, Never>
    func getThoughtFeedbacks(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtFeedbacksResponse>, Never>
    func getThoughtBookmarks(thoughtId: Int) -> AnyPublisher<NetworkResult<ThoughtBookmarksResponse>, Never>
    func getRetentionIssues(thoughtId: Int) -> AnyPublisher<NetworkResult<RetentionIssuesResponse>, Never>
}


protocol EntertainmentAPI {
    func getEntertainmentTypes() -> AnyPublisher<NetworkResult<[EntertainmentType]>, Never>
    func getEntertainmentGenres() -> AnyPublisher<NetworkResult<[EntertainmentGenre]>, Never>
    func getEntertainmentContexts() -> AnyPublisher<NetworkResult<[EntertainmentContext]>, Never>
    func getAllEntertainmentOptions() -> AnyPublisher<NetworkResult<EntertainmentOptions>, Never>
}

protocol TokenStorage {
    func saveTokens(accessToken: String, refreshToken: String)
    func getAccessToken() -> String?
    func getRefreshToken() -> String?
    func clearTokens()
}
