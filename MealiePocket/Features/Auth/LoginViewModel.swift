import Foundation
import SwiftUI

@Observable
class LoginViewModel {
    var serverURL = ""
    var username = ""
    var password = ""
    var apiKey = ""
    var isLoading = false
    var errorMessage: String?

    func performLogin(appState: AppState, mode: LoginView.LoginMode) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: serverURL), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            errorMessage = "Invalid server URL format."
            isLoading = false
            return
        }
        
        components.path = ""
        guard let baseURL = components.url else {
            errorMessage = "Could not construct base URL."
            isLoading = false
            return
        }

        switch mode {
        case .password:
            guard !username.isEmpty, !password.isEmpty else {
                 errorMessage = "Username and password are required."
                 isLoading = false
                 return
            }
            let client = MealieAPIClient(baseURL: baseURL)
            do {
                let token = try await client.login(username: username, password: password)
                await appState.login(baseURL: baseURL, token: token)
            } catch {
                errorMessage = "Login failed. Check your credentials and server URL."
            }
            
        case .apiKey:
            guard !apiKey.isEmpty else {
                errorMessage = "API Key is required."
                isLoading = false
                return
            }
            await appState.loginWithApiKey(baseURL: baseURL, apiKey: apiKey)

            if !appState.isAuthenticated {
                 errorMessage = "Login with API Key failed. Check the key and server URL."
            }
        }

         if errorMessage != nil {
              isLoading = false
         }
    }
}
