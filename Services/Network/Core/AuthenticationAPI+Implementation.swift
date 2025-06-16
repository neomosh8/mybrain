import Foundation
import Combine

extension HTTPNetworkService: AuthenticationAPI {
    
    func requestAuthCode(email: String) -> AnyPublisher<NetworkResult<RegisterResponse>, Never> {
        let body = ["email": email]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.authRequest,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: RegisterResponse.self, requiresAuth: false)
    }
    
    func verifyAuthCode(
        email: String,
        code: String,
        deviceInfo: DeviceInfo
    ) -> AnyPublisher<NetworkResult<TokenResponse>, Never> {
        let body: [String: Any] = [
            "email": email,
            "code": code,
            "device_info": [
                "device_name": deviceInfo.deviceName,
                "os_name": deviceInfo.osName,
                "app_version": deviceInfo.appVersion,
                "unique_number": deviceInfo.uniqueNumber
            ]
        ]
        
        let endpoint = APIEndpoint(
            path: "/api/v1/profiles/auth/verify/",
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        
        return request(endpoint, responseType: TokenResponse.self, requiresAuth: false)
            .handleEvents(
                receiveOutput: { result in
                    if case .success(let response) = result {
                        self.tokenStorage.saveTokens(
                            accessToken: response.access,
                            refreshToken: response.refresh
                        )
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func refreshToken(refreshToken: String) -> AnyPublisher<NetworkResult<RefreshTokenResponse>, Never> {
        let body = ["refresh": refreshToken]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.tokenRefresh,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: RefreshTokenResponse.self, requiresAuth: false)
            .handleEvents(receiveOutput: { [weak self] result in
                if case .success(let response) = result {
                    // Keep the existing refresh token and save the new access token
                    self?.tokenStorage.saveTokens(
                        accessToken: response.access,
                        refreshToken: refreshToken
                    )
                }
            })
            .eraseToAnyPublisher()
    }
    
    func googleLogin(
        idToken: String,
        deviceInfo: DeviceInfo
    ) -> AnyPublisher<NetworkResult<TokenResponse>, Never> {
        let body: [String: Any] = [
            "id_token": idToken,
            "device_info": [
                "device_name": deviceInfo.deviceName,
                "os_name": deviceInfo.osName,
                "app_version": deviceInfo.appVersion,
                "unique_number": deviceInfo.uniqueNumber
            ]
        ]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.googleLogin,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: TokenResponse.self, requiresAuth: false)
            .handleEvents(receiveOutput: { [weak self] result in
                if case .success(let response) = result {
                    self?.tokenStorage.saveTokens(
                        accessToken: response.access,
                        refreshToken: response.refresh
                    )
                }
            })
            .eraseToAnyPublisher()
    }
    
    func appleLogin(
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        deviceInfo: DeviceInfo
    ) -> AnyPublisher<NetworkResult<TokenResponse>, Never> {
        let body: [String: Any] = [
            "user_id": userId,
            "first_name": firstName ?? "",
            "last_name": lastName ?? "",
            "email": email ?? "",
            "device_info": [
                "device_name": deviceInfo.deviceName,
                "os_name": deviceInfo.osName,
                "app_version": deviceInfo.appVersion,
                "unique_number": deviceInfo.uniqueNumber
            ]
        ]
        
        let endpoint = APIEndpoint(
            path: "/api/v1/profiles/apple-login/",
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        
        return request(endpoint, responseType: TokenResponse.self, requiresAuth: false)
            .handleEvents(receiveOutput: { [weak self] result in
                if case .success(let response) = result {
                    self?.tokenStorage.saveTokens(
                        accessToken: response.access,
                        refreshToken: response.refresh
                    )
                }
            })
            .eraseToAnyPublisher()
    }
    
    func logout(
        refreshToken: String,
        deviceId: String
    ) -> AnyPublisher<NetworkResult<LogoutResponse>, Never> {
        let body = [
            "refresh": refreshToken,
            "unique_device_id": deviceId
        ]
        let endpoint = APIEndpoint(
            path: NetworkConstants.Paths.logout,
            method: .POST,
            body: try? JSONSerialization.data(withJSONObject: body)
        )
        return request(endpoint, responseType: LogoutResponse.self)
            .handleEvents(receiveOutput: { [weak self] result in
                if case .success = result {
                    self?.tokenStorage.clearTokens()
                }
            })
            .eraseToAnyPublisher()
    }
}
