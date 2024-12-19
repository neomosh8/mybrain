import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var isAuthenticated = false

    private let baseUrl = "https://brain.sorenapp.ir" // Replace with your actual base URL

    // A simple URLRequest builder
    private func request(for endpoint: String, method: String = "POST") -> URLRequest {
        let url = URL(string: baseUrl + endpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    func register(email: String, firstName: String, lastName: String, completion: @escaping (Result<String, Error>) -> Void) {
        var req = request(for: "/api/v1/profiles/register/")
        let body = RegisterRequest(email: email, first_name: firstName, last_name: lastName)
        req.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { return completion(.failure(error)) }
                guard let data = data else { return completion(.failure(NSError(domain: "", code: -1, userInfo: nil))) }
                if let resp = try? JSONDecoder().decode(RegisterResponse.self, from: data) {
                    completion(.success(resp.detail))
                } else if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errResp.detail])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            }
        }.resume()
    }

    func verifyRegistration(email: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        var req = request(for: "/api/v1/profiles/verify/")
        let deviceInfo = DeviceInfo(device_name: "iPhone", os_name: "1.0.0", app_version: "1.0.0", unique_number: "unique_device_id_123")
        let body = VerifyRequest(email: email, code: code, device_info: deviceInfo)
        req.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { return completion(.failure(error)) }
                guard let data = data else { return completion(.failure(NSError(domain: "", code: -1, userInfo: nil))) }
                if let resp = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                    self.accessToken = resp.access
                    self.refreshToken = resp.refresh
                    self.isAuthenticated = true
                    completion(.success(()))
                } else if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errResp.detail])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            }
        }.resume()
    }

    func requestLoginCode(email: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Make sure the endpoint is correct.
        // Try removing the trailing slash if you still get a 404.
        var req = request(for: "/api/v1/profiles/request/")
        
        // Create the JSON body: {"email":"rabiei.mojtaba@gmail.com"}
        let body = LoginRequest(email: email)
        req.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Request error:", error.localizedDescription)
                    return completion(.failure(error))
                }

                guard let data = data else {
                    print("No data received")
                    return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server."])))
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code:", httpResponse.statusCode)
                }

                // Print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response:", responseString)
                }

                // Try decoding success response
                if let resp = try? JSONDecoder().decode(RegisterResponse.self, from: data) {
                    return completion(.success(resp.detail))
                }

                // Try decoding error response
                if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    let errorDesc = errResp.detail
                    print("Server Error:", errorDesc)
                    return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc])))
                }

                // Fallback to a generic error if decoding fails
                let genericError = "Unknown error occurred"
                print(genericError)
                return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: genericError])))
            }
        }.resume()
    }

    func verifyLogin(email: String, code: String, completion: @escaping (Result<Void, Error>) -> Void) {
        var req = request(for: "/api/v1/profiles/login/")
        let deviceInfo = DeviceInfo(device_name: "iPhone", os_name: "1.0.0", app_version: "1.0.0", unique_number: "unique_device_id_123")
        let body = VerifyLoginRequest(email: email, code: code, device_info: deviceInfo)
        req.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error { return completion(.failure(error)) }
                guard let data = data else { return completion(.failure(NSError(domain: "", code: -1, userInfo: nil))) }

                if let resp = try? JSONDecoder().decode(TokenResponse.self, from: data) {
                    self.accessToken = resp.access
                    self.refreshToken = resp.refresh
                    self.isAuthenticated = true
                    completion(.success(()))
                } else if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errResp.detail])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            }
        }.resume()
    }
}
