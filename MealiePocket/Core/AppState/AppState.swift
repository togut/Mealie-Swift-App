import Foundation
import SwiftUI
import Combine

@Observable
class AppState {
    var apiClient: MealieAPIClient?
    var isAuthenticated: Bool = false
    var currentUserID: String?

    private let tokenKey = "com.nohitdev.MealiePocket.apiToken"
    private let baseURLKey = "com.nohitdev.MealiePocket.baseURL"
    private let userIDKey = "com.nohitdev.MealiePocket.userID"
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let tokenData = KeychainHelper.load(key: tokenKey),
           let urlData = KeychainHelper.load(key: baseURLKey),
           let userIDData = KeychainHelper.load(key: userIDKey),
           let token = String(data: tokenData, encoding: .utf8),
           let urlString = String(data: urlData, encoding: .utf8),
           let userID = String(data: userIDData, encoding: .utf8),
           let url = URL(string: urlString) {
            
            let client = MealieAPIClient(baseURL: url)
            client.setToken(token)
            
            self.apiClient = client
            self.currentUserID = userID
            self.isAuthenticated = true
        }
        
        setupUnauthorizedObserver()
    }
    
    private func setupUnauthorizedObserver() {
        NotificationCenter.default.publisher(for: .userUnauthorizedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logout()
            }
            .store(in: &cancellables)
    }
    
    func login(baseURL: URL, token: String) async {
        let apiClient = MealieAPIClient(baseURL: baseURL)
        apiClient.setToken(token)
        
        do {
            let user = try await apiClient.fetchCurrentUser()
            
            guard let tokenData = token.data(using: .utf8),
                  let urlData = baseURL.absoluteString.data(using: .utf8),
                  let userIDData = user.id.data(using: .utf8) else {
                await MainActor.run { self.logout() }
                return
            }

            let tokenStatus = KeychainHelper.save(key: tokenKey, data: tokenData)
            let urlStatus = KeychainHelper.save(key: baseURLKey, data: urlData)
            let userStatus = KeychainHelper.save(key: userIDKey, data: userIDData)
            
            guard tokenStatus == noErr, urlStatus == noErr, userStatus == noErr else {
                _ = KeychainHelper.delete(key: tokenKey)
                _ = KeychainHelper.delete(key: baseURLKey)
                _ = KeychainHelper.delete(key: userIDKey)
                await MainActor.run { self.logout() }
                return
            }
            
            await MainActor.run {
                self.apiClient = apiClient
                self.currentUserID = user.id
                self.isAuthenticated = true
            }
        } catch {
            await MainActor.run {
                logout()
            }
        }
    }

    @MainActor
    func logout() {
        _ = KeychainHelper.delete(key: tokenKey)
        _ = KeychainHelper.delete(key: baseURLKey)
        _ = KeychainHelper.delete(key: userIDKey)
        
        self.apiClient?.setToken("")
        self.apiClient = nil
        self.currentUserID = nil
        self.isAuthenticated = false
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
