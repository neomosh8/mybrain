import Foundation
import Combine

// MARK: - Core Protocols

protocol HTTPNetworkServiceProtocol: AuthenticationAPI, ProfileAPI, ThoughtsAPI {}

protocol AuthenticationAPI {
    func requestAuthCode(email: String) -> AnyPublisher<NetworkResult<RegisterResponse>, Never>
    func verifyAuthCode(email: String, code: String, phoneInfo: PhoneInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func refreshToken(refreshToken: String) -> AnyPublisher<NetworkResult<RefreshTokenResponse>, Never>
    func googleLogin(idToken: String, phoneInfo: PhoneInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func appleLogin(userId: String, firstName: String?, lastName: String?, email: String?, phoneInfo: PhoneInfo) -> AnyPublisher<NetworkResult<TokenResponse>, Never>
    func logout(refreshToken: String, deviceId: String) -> AnyPublisher<NetworkResult<LogoutResponse>, Never>
}

protocol ProfileAPI {
    func getProfile() -> AnyPublisher<NetworkResult<UserProfile>, Never>
    func updateProfile(firstName: String?, lastName: String?, birthdate: String?, gender: String?) -> AnyPublisher<NetworkResult<UserProfile>, Never>
    func uploadAvatar(imageData: Data) -> AnyPublisher<NetworkResult<UserProfile>, Never>
    func deleteAvatar() -> AnyPublisher<NetworkResult<UserProfile>, Never>
    func updatePreferences(types: [PreferenceItem]?, genres: [PreferenceItem]?, contexts: [PreferenceItem]?) -> AnyPublisher<NetworkResult<SimpleStringResponse>, Never>
    func listDevices() -> AnyPublisher<NetworkResult<[UserDevice]>, Never>
    func terminateDevice(deviceId: String, currentDeviceId: String) -> AnyPublisher<NetworkResult<DeviceTerminationResponse>, Never>
    func deleteAccount() -> AnyPublisher<NetworkResult<DeleteAccountResponse>, Never>
}

protocol ThoughtsAPI {
    func createThoughtFromURL(url: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func createThoughtFromText(text: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func createThoughtFromFile(fileData: Data, contentType: String, fileName: String) -> AnyPublisher<NetworkResult<ThoughtCreationResponse>, Never>
    func getAllThoughts() -> AnyPublisher<NetworkResult<[Thought]>, Never>
    func getThoughtStatus(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtStatus>, Never>
    func resetThoughtProgress(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never>
    func retryFailedThought(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtOperationResponse>, Never>
    func passChapters(thoughtId: String, upToChapter: Int) -> AnyPublisher<NetworkResult<PassChaptersResponse>, Never>
    func summarizeChapters(thoughtId: String) -> AnyPublisher<NetworkResult<SummarizeResponse>, Never>
    func archiveThought(thoughtId: String) -> AnyPublisher<NetworkResult<ArchiveThoughtResponse>, Never>
    func getThoughtFeedbacks(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtFeedbacksResponse>, Never>
    func getThoughtBookmarks(thoughtId: String) -> AnyPublisher<NetworkResult<ThoughtBookmarksResponse>, Never>
    func getRetentionIssues(thoughtId: String) -> AnyPublisher<NetworkResult<RetentionIssuesResponse>, Never>
}

protocol TokenStorage {
    func saveTokens(accessToken: String, refreshToken: String)
    func getAccessToken() -> String?
    func getRefreshToken() -> String?
    func clearTokens()
}
