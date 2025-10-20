import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case unauthorized
}

class MealieAPIClient {
    let baseURL: URL
    private var token: String?

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func setToken(_ token: String) {
        self.token = token
    }

    func login(username: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "username=\(username)&password=\(password)"
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        self.token = tokenResponse.accessToken
        return tokenResponse.accessToken
    }

    func fetchAllRecipes() async throws -> [RecipeSummary] {
        let url = baseURL.appendingPathComponent("api/recipes")
        var request = URLRequest(url: url)
        
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let paginatedResponse = try decoder.decode(PaginatedRecipes.self, from: data)
        return paginatedResponse.items
    }
    
    func fetchRecipeDetail(slug: String) async throws -> RecipeDetail {
        let url = baseURL.appendingPathComponent("api/recipes/\(slug)")
        var request = URLRequest(url: url)

        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RecipeDetail.self, from: data)
    }
}

