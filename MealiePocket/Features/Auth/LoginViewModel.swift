import Foundation
import SwiftUI

@Observable
class LoginViewModel {
    var serverURL = ""
    var username = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    func login(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: serverURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
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

        let client = MealieAPIClient(baseURL: baseURL)

        do {
            let token = try await client.login(username: username, password: password)
            await appState.login(baseURL: baseURL, token: token)
        } catch {
            errorMessage = "Login failed. Check your credentials and server URL."
        }
        
        isLoading = false
    }
}
