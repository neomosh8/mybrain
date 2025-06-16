import Foundation
import Combine
import UIKit

final class HTTPNetworkService: HTTPNetworkServiceProtocol {
    private let baseURL: String
    internal let tokenStorage: TokenStorage
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(baseURL: String, tokenStorage: TokenStorage) {
        self.baseURL = baseURL
        self.tokenStorage = tokenStorage
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Private Request Method
    internal func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type,
        requiresAuth: Bool = true
    ) -> AnyPublisher<NetworkResult<T>, Never> {
        
        guard let url = buildURL(for: endpoint) else {
            return Just(.failure(.invalidURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Add default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(NetworkConstants.userTimezone, forHTTPHeaderField: "User-Timezone")
        
        // Add custom headers
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // Add authorization if required and available
        if requiresAuth, let token = tokenStorage.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if present
        request.httpBody = endpoint.body
        
        return session.dataTaskPublisher(for: request)
            .map { data, response -> NetworkResult<T> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure(.invalidResponse)
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        let decoded = try self.decoder.decode(T.self, from: data)
                        return .success(decoded)
                    } catch {
                        return .failure(.decodingFailed(error))
                    }
                case 401:
                    return .failure(.unauthorized)
                case 400...499:
                    let message = String(data: data, encoding: .utf8) ?? "Client error"
                    return .failure(.clientError(httpResponse.statusCode, message))
                case 500...599:
                    let message = String(data: data, encoding: .utf8) ?? "Server error"
                    return .failure(.serverError(httpResponse.statusCode, message))
                default:
                    return .failure(.unknown)
                }
            }
            .catch { error -> Just<NetworkResult<T>> in
                Just(.failure(.requestFailed(error)))
            }
            .eraseToAnyPublisher()
    }
    
    internal func buildURL(for endpoint: APIEndpoint) -> URL? {
        guard let baseURL = URL(string: baseURL) else { return nil }
        
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = endpoint.path
        components.queryItems = endpoint.queryItems
        
        return components.url
    }
}
