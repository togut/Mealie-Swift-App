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
    private let recipesPerPage = 20

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
    
    func fetchCurrentUser() async throws -> User {
        let url = baseURL.appendingPathComponent("api/users/self")
        var request = URLRequest(url: url)
        
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(User.self, from: data)
    }

    func fetchRecipes(page: Int, orderBy: String, orderDirection: String, paginationSeed: String?, queryFilter: String? = nil) async throws -> PaginatedRecipes {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/recipes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(recipesPerPage)"),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "orderDirection", value: orderDirection)
        ]
        
        if let seed = paginationSeed {
            components?.queryItems?.append(URLQueryItem(name: "paginationSeed", value: seed))
        }
        
        if let filter = queryFilter {
            components?.queryItems?.append(URLQueryItem(name: "queryFilter", value: filter))
        }
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PaginatedRecipes.self, from: data)
    }
    
    func fetchFavorites(userID: String) async throws -> [UserRating] {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites")
        print(url)
        var request = URLRequest(url: url)
        
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let ratingsResponse = try decoder.decode(UserRatingsResponse.self, from: data)
        return ratingsResponse.ratings
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
    
    func addFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
    }

    func removeFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        guard let token = token else { throw APIError.unauthorized }
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
    }
}
