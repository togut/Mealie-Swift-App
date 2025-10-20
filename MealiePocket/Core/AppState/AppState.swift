import Foundation
import SwiftUI

@Observable
class AppState {
    var apiClient: MealieAPIClient?
    var isAuthenticated: Bool = false

    private let tokenKey = "com.nohitdev.MealiePocket.apiToken"
    private let baseURLKey = "com.nohitdev.MealiePocket.baseURL"

    init() {
        if let tokenData = KeychainHelper.load(key: tokenKey),
           let urlData = KeychainHelper.load(key: baseURLKey),
           let token = String(data: tokenData, encoding: .utf8),
           let urlString = String(data: urlData, encoding: .utf8),
           let url = URL(string: urlString) {
            
            self.apiClient = MealieAPIClient(baseURL: url)
            self.apiClient?.setToken(token)
            self.isAuthenticated = true
        }
    }
    
    func login(baseURL: URL, token: String) {
        guard let tokenData = token.data(using: .utf8),
              let urlData = baseURL.absoluteString.data(using: .utf8) else {
            return
        }

        let tokenStatus = KeychainHelper.save(key: tokenKey, data: tokenData)
        let urlStatus = KeychainHelper.save(key: baseURLKey, data: urlData)
        
        if tokenStatus == noErr && urlStatus == noErr {
            self.apiClient = MealieAPIClient(baseURL: baseURL)
            self.apiClient?.setToken(token)
            self.isAuthenticated = true
        }
    }

    func logout() {
        _ = KeychainHelper.delete(key: tokenKey)
        _ = KeychainHelper.delete(key: baseURLKey)
        
        self.apiClient = nil
        self.isAuthenticated = false
    }
}
