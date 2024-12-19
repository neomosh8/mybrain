import SwiftUI
import SwiftData

class AuthViewModel: ObservableObject {
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var isAuthenticated = false

    private let baseUrl = "https://brain.sorenapp.ir"
    
    private func request(for endpoint: String, method: String = "POST") -> URLRequest {
        let url = URL(string: baseUrl + endpoint)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    // Load tokens from SwiftData when app starts
    func loadFromSwiftData(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<AuthData>(predicate: #Predicate { $0.id == "user_auth_data" })
        if let authData = try? context.fetch(fetchDescriptor).first {
            self.accessToken = authData.accessToken
            self.refreshToken = authData.refreshToken
            self.isAuthenticated = authData.isLoggedIn
        }
    }

    // Save tokens to SwiftData whenever you update them
    private func saveToSwiftData(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<AuthData>(predicate: #Predicate { $0.id == "user_auth_data" })
        let existing = try? context.fetch(fetchDescriptor)
        let authData = existing?.first ?? AuthData()

        authData.accessToken = self.accessToken
        authData.refreshToken = self.refreshToken
        authData.isLoggedIn = self.isAuthenticated

        context.insert(authData) // If it's new, otherwise this does nothing
        try? context.save()
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

    func verifyRegistration(email: String, code: String, context: ModelContext, completion: @escaping (Result<Void, Error>) -> Void) {
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
                    self.saveToSwiftData(context: context)
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
        var req = request(for: "/api/v1/profiles/request/")
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

                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response:", responseString)
                }

                if let resp = try? JSONDecoder().decode(RegisterResponse.self, from: data) {
                    return completion(.success(resp.detail))
                }

                if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    let errorDesc = errResp.detail
                    print("Server Error:", errorDesc)
                    return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDesc])))
                }

                let genericError = "Unknown error occurred"
                print(genericError)
                return completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: genericError])))
            }
        }.resume()
    }

    func verifyLogin(email: String, code: String, context: ModelContext, completion: @escaping (Result<Void, Error>) -> Void) {
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
                    self.saveToSwiftData(context: context)
                    completion(.success(()))
                } else if let errResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errResp.detail])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            }
        }.resume()
    }

    // Example logout function
    func logout(context: ModelContext) {
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
        saveToSwiftData(context: context)
    }
}
