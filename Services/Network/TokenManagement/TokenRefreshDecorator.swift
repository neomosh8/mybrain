import Combine
import UIKit
import Foundation

class TokenRefreshDecorator: NetworkService {
    private let decoratedService: NetworkService
    private let authService: AuthNetworkService
    private let tokenStorage: TokenStorage
    private var isRefreshing = false
    private var refreshPublisher: AnyPublisher<TokenResponse, NetworkError>?
    private let lock = NSLock()
    
    var onTokensInvalid: (() -> Void)?
    
    init(
        decoratedService: NetworkService,
        authService: AuthNetworkService,
        tokenStorage: TokenStorage
    ) {
        self.decoratedService = decoratedService
        self.authService = authService
        self.tokenStorage = tokenStorage
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        return decoratedService.request(endpoint)
            .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                guard let self = self else {
                    return Fail(error: NetworkError.unknown)
                        .eraseToAnyPublisher()
                }
                
                if error == NetworkError.unauthorized {
                    return self.refreshTokenAndRetry(endpoint)
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func uploadFile(_ fileURL: URL, to endpoint: Endpoint, fileKey: String) -> AnyPublisher<UploadResponse, NetworkError> {
        return decoratedService
            .uploadFile(fileURL, to: endpoint, fileKey: fileKey)
            .catch { [weak self] error -> AnyPublisher<UploadResponse, NetworkError> in
                guard let self = self else {
                    return Fail(error: NetworkError.unknown)
                        .eraseToAnyPublisher()
                }
                
                if error == NetworkError.unauthorized {
                    return self.refreshTokenAndRetryUpload(
                        fileURL,
                        endpoint: endpoint,
                        fileKey: fileKey
                    )
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchImage(from urlString: String) -> AnyPublisher<UIImage?, Never> {
        return decoratedService.fetchImage(from: urlString)
    }
    
    private func refreshTokenAndRetry<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, NetworkError> {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            print("No refresh token available - triggering force logout")
            DispatchQueue.main.async {
                self.onTokensInvalid?()
            }
            return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        if isRefreshing, let existingPublisher = refreshPublisher {
            return existingPublisher
                .flatMap { _ -> AnyPublisher<T, NetworkError> in
                    return self.decoratedService.request(endpoint)
                }
                .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                    // If refresh succeeded but retry still fails with 401, force logout
                    if error == NetworkError.unauthorized {
                        print("Token refresh succeeded but request still unauthorized - force logout")
                        DispatchQueue.main.async {
                            self?.onTokensInvalid?()
                        }
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        let publisher = authService.refreshToken(token: refreshToken)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    self?.refreshPublisher = nil
                    
                    // Check if refresh failed
                    if case .failure(let error) = completion {
                        print("Token refresh failed: \(error) - triggering force logout")
                        if error == NetworkError.unauthorized {
                            DispatchQueue.main.async {
                                self?.onTokensInvalid?()
                            }
                        }
                    }
                },
                receiveCancel: { [weak self] in
                    self?.isRefreshing = false
                    self?.refreshPublisher = nil
                }
            )
            .share()
            .eraseToAnyPublisher()
        
        self.refreshPublisher = publisher
        
        return publisher
            .flatMap { _ -> AnyPublisher<T, NetworkError> in
                return self.decoratedService.request(endpoint)
            }
            .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                // If refresh succeeded but retry still fails with 401, force logout
                if error == NetworkError.unauthorized {
                    print("Token refresh succeeded but request still unauthorized - force logout")
                    DispatchQueue.main.async {
                        self?.onTokensInvalid?()
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func refreshTokenAndRetryUpload(_ fileURL: URL, endpoint: Endpoint, fileKey: String) -> AnyPublisher<UploadResponse, NetworkError> {
        guard let refreshToken = tokenStorage.getRefreshToken() else {
            print("No refresh token available for upload - triggering force logout")
            DispatchQueue.main.async {
                self.onTokensInvalid?()
            }
            return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        if isRefreshing, let existingPublisher = refreshPublisher {
            return existingPublisher
                .flatMap { _ -> AnyPublisher<UploadResponse, NetworkError> in
                    return self.decoratedService
                        .uploadFile(fileURL, to: endpoint, fileKey: fileKey)
                }
                .catch { [weak self] error -> AnyPublisher<UploadResponse, NetworkError> in
                    if error == NetworkError.unauthorized {
                        print("Upload token refresh succeeded but request still unauthorized - force logout")
                        DispatchQueue.main.async {
                            self?.onTokensInvalid?()
                        }
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        let publisher = authService.refreshToken(token: refreshToken)
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    self?.isRefreshing = false
                    self?.refreshPublisher = nil
                    
                    if case .failure(let error) = completion {
                        print("Upload token refresh failed: \(error) - triggering force logout")
                        if error == NetworkError.unauthorized {
                            DispatchQueue.main.async {
                                self?.onTokensInvalid?()
                            }
                        }
                    }
                },
                receiveCancel: { [weak self] in
                    self?.isRefreshing = false
                    self?.refreshPublisher = nil
                }
            )
            .share()
            .eraseToAnyPublisher()
        
        self.refreshPublisher = publisher
        
        return publisher
            .flatMap { _ -> AnyPublisher<UploadResponse, NetworkError> in
                return self.decoratedService
                    .uploadFile(fileURL, to: endpoint, fileKey: fileKey)
            }
            .catch { [weak self] error -> AnyPublisher<UploadResponse, NetworkError> in
                if error == NetworkError.unauthorized {
                    print("Upload token refresh succeeded but request still unauthorized - force logout")
                    DispatchQueue.main.async {
                        self?.onTokensInvalid?()
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
