import SwiftUI
import Combine
import SwiftData

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var accessToken: String?
    @Published var refreshToken: String?
    @Published var isAuthenticated = false
    
    @Published var appleAuthManager = AppleAuthManager()
    @Published var googleAuthManager = GoogleAuthManager()
    
    // MARK: - Private Properties
    
    var serverConnect: ServerConnect?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(serverConnect: ServerConnect? = nil) {
        self.serverConnect = serverConnect
        
        // Listen for tokens from social auth
        NotificationCenter.default.publisher(for: .didReceiveAuthTokens)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self = self else { return }
                if let access = note.userInfo?["access"] as? String,
                   let refresh = note.userInfo?["refresh"] as? String {
                    self.accessToken = access
                    self.refreshToken = refresh
                    self.isAuthenticated = true
                }
            }
            .store(in: &cancellables)
        
        setupAppleAuthNotifications()
        
        setupGoogleAuthNotifications()
    }
    
    // MARK: - Private Methods
    
    
    private func setupAppleAuthNotifications() {
        NotificationCenter.default.publisher(for: .appleAuthSuccess)
            .sink { [weak self] notification in
                guard let self = self,
                      let userId = notification.userInfo?["userId"] as? String,
                      let firstName = notification.userInfo?["firstName"] as? String,
                      let lastName = notification.userInfo?["lastName"] as? String,
                      let email = notification.userInfo?["email"] as? String else {
                    return
                }
                
                print("Apple auth successful for \(firstName) \(lastName)")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .appleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    print("Apple Sign-In failed: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupGoogleAuthNotifications() {
        NotificationCenter.default.publisher(for: .googleAuthSuccess)
            .sink { [weak self] notification in
                guard let self = self,
                      let idToken = notification.userInfo?["idToken"] as? String else {
                    return
                }
                
                print("Google auth successful with token")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .googleAuthFailure)
            .sink { notification in
                if let error = notification.userInfo?["error"] as? Error {
                    print(
                        "Google Sign-In failed: \(error.localizedDescription)"
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func initializeWithServerConnect(_ serverConnect: ServerConnect) {
        self.serverConnect = serverConnect
    }
    
    func loadFromSwiftData(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        if let authData = try? context.fetch(fetchDescriptor).first {
            self.accessToken = authData.accessToken
            self.refreshToken = authData.refreshToken
            self.isAuthenticated = authData.isLoggedIn
        }
    }
    
    func register(
        email: String,
        firstName: String,
        lastName: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect
            .register(email: email, firstName: firstName, lastName: lastName)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { response in
                    completion(.success(response.detail))
                }
            )
            .store(in: &cancellables)
    }
    
    func verifyRegistration(
        email: String,
        code: String,
        context: ModelContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let deviceInfo = createDeviceInfo()
        
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect
            .verifyRegistration(
                email: email,
                code: code,
                deviceInfo: deviceInfo
            )
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { tokenResponse in
                    self.accessToken = tokenResponse.access
                    self.refreshToken = tokenResponse.refresh
                    self.isAuthenticated = true
                    
                    SharedDataManager.saveToken(tokenResponse.access)
                    
                    completion(.success(()))
                }
            )
            .store(in: &cancellables)
    }
    
    func requestLoginCode(
        email: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect.requestLoginCode(email: email)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { response in
                    completion(.success(response.detail))
                }
            )
            .store(in: &cancellables)
    }
    
    func verifyLogin(
        email: String,
        code: String,
        context: ModelContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let deviceInfo = createDeviceInfo()
        
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect.login(email: email, code: code, deviceInfo: deviceInfo)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { tokenResponse in
                    self.accessToken = tokenResponse.access
                    self.refreshToken = tokenResponse.refresh
                    self.isAuthenticated = true
                    
                    SharedDataManager.saveToken(tokenResponse.access)
                    
                    completion(.success(()))
                }
            )
            .store(in: &cancellables)
    }
    
    func logout(
        context: ModelContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        guard let refreshToken = self.refreshToken else {
            self.accessToken = nil
            self.refreshToken = nil
            self.isAuthenticated = false
            
            SharedDataManager.saveToken(nil)
            
            completion(.success(()))
            return
        }
        
        serverConnect.logout(refreshToken: refreshToken)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { _ in
                    self.accessToken = nil
                    self.refreshToken = nil
                    self.isAuthenticated = false
                    
                    SharedDataManager.saveToken(nil)
                    
                    completion(.success(()))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Logout locally (without server communication)
    func logout(context: ModelContext) {
        self.accessToken = nil
        self.refreshToken = nil
        self.isAuthenticated = false
        
        SharedDataManager.saveToken(nil)
        
        let fetchDescriptor = FetchDescriptor<AuthData>(
            predicate: #Predicate { $0.id == "user_auth_data"
            })
        if let authData = try? context.fetch(fetchDescriptor).first {
            authData.accessToken = nil
            authData.refreshToken = nil
            authData.isLoggedIn = false
            try? context.save()
        }
    }
    
    
    func authenticateWithApple(
        context: ModelContext,
        userId: String,
        firstName: String?,
        lastName: String?,
        email: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let deviceInfo = createDeviceInfo()
        
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect
            .authenticateWithApple(
                userId: userId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                deviceInfo: deviceInfo
            )
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { tokenResponse in
                    self.accessToken = tokenResponse.access
                    self.refreshToken = tokenResponse.refresh
                    self.isAuthenticated = true
                    
                    SharedDataManager.saveToken(tokenResponse.access)
                    
                    completion(.success(()))
                }
            )
            .store(in: &cancellables)
    }
    
    func authenticateWithGoogle(
        context: ModelContext,
        idToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let deviceInfo = createDeviceInfo()
        
        guard let serverConnect = serverConnect else {
            completion(
                .failure(
                    NSError(
                        domain: "AuthViewModel",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Server connection not initialized"]
                    )
                )
            )
            return
        }
        
        serverConnect
            .authenticateWithGoogle(idToken: idToken, deviceInfo: deviceInfo)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { tokenResponse in
                    self.accessToken = tokenResponse.access
                    self.refreshToken = tokenResponse.refresh
                    self.isAuthenticated = true
                    
                    SharedDataManager.saveToken(tokenResponse.access)
                    
                    completion(.success(()))
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func createDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            device_name: UIDevice.current.name,
            os_name: UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            unique_number: UIDevice.current.identifierForVendor?.uuidString ?? "unique_device_id_123"
        )
    }
}
