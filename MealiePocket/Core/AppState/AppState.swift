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
    private let authMethodKey = "com.nohitdev.MealiePocket.authMethod"

    enum AuthMethod: String {
        case token = "token"
        case apiKey = "apiKey"
    }
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        guard let urlData = KeychainHelper.load(key: baseURLKey),
              let urlString = String(data: urlData, encoding: .utf8),
              let url = URL(string: urlString),
              let authMethodData = KeychainHelper.load(key: authMethodKey),
              let authMethodString = String(data: authMethodData, encoding: .utf8),
              let _ = AuthMethod(rawValue: authMethodString),
              let tokenData = KeychainHelper.load(key: tokenKey),
              let token = String(data: tokenData, encoding: .utf8)
        else {
            self.isAuthenticated = false
            setupNotificationObservers()
            return
        }

        let userIDData = KeychainHelper.load(key: userIDKey)
        let userID = userIDData != nil ? String(data: userIDData!, encoding: .utf8) : nil

        let client = MealieAPIClient(baseURL: url)
        client.setToken(token)
            
        self.apiClient = client
        self.currentUserID = userID
        self.isAuthenticated = true
        
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .userUnauthorizedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.logout()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .tokenRefreshedNotification)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.object as? String }
            .sink { [weak self] newToken in
                 guard let self = self else { return }
                 if let tokenData = newToken.data(using: .utf8) {
                     let status = KeychainHelper.save(key: self.tokenKey, data: tokenData)
                     if status != noErr {
                         print("Erreur Keychain: Sauvegarde du token rafraîchi échouée")
                         self.logout()
                     } else {
                          print("Token rafraîchi et sauvegardé.")
                          self.apiClient?.setToken(newToken)
                     }
                 }
            }
            .store(in: &cancellables)
    }

    func login(baseURL: URL, token: String) async {
        let apiClient = MealieAPIClient(baseURL: baseURL)
        apiClient.setToken(token)
        
        do {
            let user = try await apiClient.fetchCurrentUser()
            await saveCredentials(baseURL: baseURL, token: token, userID: user.id, authMethod: .token)
            
            await MainActor.run {
                self.apiClient = apiClient
                self.currentUserID = user.id
                self.isAuthenticated = true
            }
        } catch {
             await MainActor.run { logout() }
        }
    }

     func loginWithApiKey(baseURL: URL, apiKey: String) async {
         let apiClient = MealieAPIClient(baseURL: baseURL)
         apiClient.setToken(apiKey)
         
         do {
             let user = try await apiClient.fetchCurrentUser()

             await saveCredentials(baseURL: baseURL, token: apiKey, userID: user.id, authMethod: .apiKey)
             
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

    private func saveCredentials(baseURL: URL, token: String, userID: String, authMethod: AuthMethod) async {
        guard let tokenData = token.data(using: .utf8),
              let urlData = baseURL.absoluteString.data(using: .utf8),
              let userIDData = userID.data(using: .utf8),
              let authMethodData = authMethod.rawValue.data(using: .utf8)
        else {
             await MainActor.run { logout() }
            return
        }

        let tokenStatus = KeychainHelper.save(key: tokenKey, data: tokenData)
        let urlStatus = KeychainHelper.save(key: baseURLKey, data: urlData)
        let userStatus = KeychainHelper.save(key: userIDKey, data: userIDData)
        let authMethodStatus = KeychainHelper.save(key: authMethodKey, data: authMethodData)
        
        guard tokenStatus == noErr, urlStatus == noErr, userStatus == noErr, authMethodStatus == noErr else {
            _ = KeychainHelper.delete(key: tokenKey)
            _ = KeychainHelper.delete(key: baseURLKey)
            _ = KeychainHelper.delete(key: userIDKey)
            _ = KeychainHelper.delete(key: authMethodKey)
            await MainActor.run { logout() }
            return
        }
    }


    @MainActor
    func logout() {
        _ = KeychainHelper.delete(key: tokenKey)
        _ = KeychainHelper.delete(key: baseURLKey)
        _ = KeychainHelper.delete(key: userIDKey)
        _ = KeychainHelper.delete(key: authMethodKey)
        
        self.apiClient?.setToken(nil)
        self.apiClient = nil
        self.currentUserID = nil
        self.isAuthenticated = false
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
