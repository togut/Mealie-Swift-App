import Foundation
import SwiftUI

@Observable
class AppState {
    var apiClient: MealieAPIClient?
    var isAuthenticated: Bool = false
    var currentUserID: String?

    private let tokenKey = "com.nohitdev.MealiePocket.apiToken"
    private let baseURLKey = "com.nohitdev.MealiePocket.baseURL"
    private let userIDKey = "com.nohitdev.MealiePocket.userID"

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
    }
    
    func login(baseURL: URL, token: String) async {
        let apiClient = MealieAPIClient(baseURL: baseURL)
        apiClient.setToken(token)
        
        do {
            let user = try await apiClient.fetchCurrentUser()
            
            guard let tokenData = token.data(using: .utf8),
                  let urlData = baseURL.absoluteString.data(using: .utf8),
                  let userIDData = user.id.data(using: .utf8) else {
                return
            }

            _ = KeychainHelper.save(key: tokenKey, data: tokenData)
            _ = KeychainHelper.save(key: baseURLKey, data: urlData)
            _ = KeychainHelper.save(key: userIDKey, data: userIDData)
            
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

    func logout() {
        _ = KeychainHelper.delete(key: tokenKey)
        _ = KeychainHelper.delete(key: baseURLKey)
        _ = KeychainHelper.delete(key: userIDKey)
        
        self.apiClient = nil
        self.currentUserID = nil
        self.isAuthenticated = false
    }
}
