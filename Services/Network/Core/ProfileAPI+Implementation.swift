import Foundation
import Combine

extension HTTPNetworkService: ProfileAPI {
    
    func getProfile() -> AnyPublisher<NetworkResult<UserProfile>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.profile,
            method: .GET
        )
        return request(endpoint, responseType: UserProfile.self)
    }
    
    func updateProfile(
        firstName: String?,
        lastName: String?,
        birthdate: String?,
        gender: String?
    ) -> AnyPublisher<NetworkResult<UserProfile>, Never> {
        var body: [String: Any] = [:]
        if let firstName = firstName { body["first_name"] = firstName }
        if let lastName = lastName { body["last_name"] = lastName }
        if let birthdate = birthdate { body["birthdate"] = birthdate }
        if let gender = gender { body["gender"] = gender }
        
        body["onboarded"] = true
        
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.updateProfile,
            method: .PUT,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: UserProfile.self)
    }
    
    func uploadAvatar(imageData: Data) -> AnyPublisher<NetworkResult<UserProfile>, Never> {
        let boundary = UUID().uuidString
        let body = createMultipartBody(imageData: imageData, boundary: boundary)
        
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.uploadAvatar,
            method: .POST,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"],
            body: body
        )
        return request(endpoint, responseType: UserProfile.self)
    }
    
    func deleteAvatar() -> AnyPublisher<NetworkResult<UserProfile>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.deleteAvatar,
            method: .DELETE
        )
        return request(endpoint, responseType: UserProfile.self)
    }
    
    private func createMultipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    func updatePreferences(
        types: [PreferenceItem]?,
        genres: [PreferenceItem]?,
        contexts: [PreferenceItem]?
    ) -> AnyPublisher<NetworkResult<SimpleStringResponse>, Never> {
        var body: [String: Any] = [:]
        if let types = types {
            body["types"] = types.map { ["type": $0.id, "liked": $0.liked] }
        }
        if let genres = genres {
            body["genres"] = genres.map { ["genre": $0.id, "liked": $0.liked] }
        }
        if let contexts = contexts {
            body["contexts"] = contexts.map { ["context": $0.id, "liked": $0.liked] }
        }
        
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.updateProfile,
            method: .PUT,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: SimpleStringResponse.self)
    }
    
    func listDevices() -> AnyPublisher<NetworkResult<[UserDevice]>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.devices,
            method: .GET
        )
        return request(endpoint, responseType: [UserDevice].self)
    }
    
    func terminateDevice(
        deviceId: String,
        currentDeviceId: String
    ) -> AnyPublisher<NetworkResult<DeviceTerminationResponse>, Never> {
        let body = [
            "unique_device_id": deviceId,
            "current_device_id": currentDeviceId
        ]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.deviceLogout,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: DeviceTerminationResponse.self)
    }
    
    func deleteAccount() -> AnyPublisher<NetworkResult<DeleteAccountResponse>, Never> {
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.deleteAccount,
            method: .DELETE
        )
        return request(endpoint, responseType: DeleteAccountResponse.self)
    }
}
