import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(statusCode: Int, error: Error?)
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case encodingError(Error)
    case unknown(Error)
}

extension Notification.Name {
    static let userUnauthorizedNotification = Notification.Name("userUnauthorizedNotification")
}

class MealieAPIClient {
    let baseURL: URL
    private var token: String?
    private let defaultRecipesPerPage = 20
    private let session: URLSession

    struct NoReply: Decodable {}

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setToken(_ token: String) {
        self.token = token
    }

    private func performRequest<T: Decodable>(for request: URLRequest) async throws -> T {
        var mutableRequest = request
        
        if let token = self.token {
            mutableRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: mutableRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                NotificationCenter.default.post(name: .userUnauthorizedNotification, object: nil)
                throw APIError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                 throw APIError.requestFailed(statusCode: httpResponse.statusCode, error: nil)
            }
            
            if T.self == NoReply.self {
                 if let noReply = NoReply() as? T {
                     return noReply
                 } else {
                     throw APIError.decodingError(NSError(domain: "MealieAPIClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not cast to NoReply"]))
                 }
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
             throw error
        } catch let urlError as URLError {
             throw APIError.requestFailed(statusCode: urlError.code.rawValue, error: urlError)
        } catch {
             throw APIError.unknown(error)
        }
    }

    func login(username: String, password: String) async throws -> String {
        let url = baseURL.appendingPathComponent("api/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "username=\(username)&password=\(password)"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                 throw APIError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                 throw APIError.requestFailed(statusCode: httpResponse.statusCode, error: nil)
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            self.token = tokenResponse.accessToken
            return tokenResponse.accessToken
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown(error)
        }
    }
    
    func fetchCurrentUser() async throws -> User {
        let url = baseURL.appendingPathComponent("api/users/self")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func fetchAllRecipes(orderBy: String, orderDirection: String, paginationSeed: String?) async throws -> [RecipeSummary] {
        var allRecipes: [RecipeSummary] = []
        var currentPage = 1
        var totalPages = 1
        
        repeat {
            let paginatedResponse: PaginatedRecipes = try await fetchRecipes(
                page: currentPage,
                orderBy: orderBy,
                orderDirection: orderDirection,
                paginationSeed: paginationSeed,
                perPage: 100
            )
            allRecipes.append(contentsOf: paginatedResponse.items)
            totalPages = paginatedResponse.totalPages
            currentPage += 1
        } while currentPage <= totalPages && totalPages > 0
        
        return allRecipes
    }

    func fetchRecipes(page: Int, orderBy: String, orderDirection: String, paginationSeed: String?, queryFilter: String? = nil, perPage: Int? = nil) async throws -> PaginatedRecipes {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/recipes"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(perPage ?? defaultRecipesPerPage)"),
            URLQueryItem(name: "orderBy", value: orderBy),
            URLQueryItem(name: "orderDirection", value: orderDirection)
        ]
        
        if let seed = paginationSeed {
            components?.queryItems?.append(URLQueryItem(name: "paginationSeed", value: seed))
        }
        
        if let filter = queryFilter, !filter.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "queryFilter", value: filter))
        }
        
        guard let url = components?.url else { throw APIError.invalidURL }
        
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }

    func fetchRatings(userID: String) async throws -> [UserRating] {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/ratings")
        let request = URLRequest(url: url)
        let response: UserRatingsResponse = try await performRequest(for: request)
        return response.ratings
    }

    func fetchFavorites(userID: String) async throws -> [UserRating] {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites")
        let request = URLRequest(url: url)
        let response: UserRatingsResponse = try await performRequest(for: request)
        return response.ratings
    }
    
    func fetchRecipeDetail(slug: String) async throws -> RecipeDetail {
        let url = baseURL.appendingPathComponent("api/recipes/\(slug)")
        let request = URLRequest(url: url)
        return try await performRequest(for: request)
    }
    
    func addFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _: NoReply = try await performRequest(for: request)
    }

    func removeFavorite(userID: String, slug: String) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/favorites/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let _: NoReply = try await performRequest(for: request)
    }

    func setRating(userID: String, slug: String, rating: Double) async throws {
        let url = baseURL.appendingPathComponent("api/users/\(userID)/ratings/\(slug)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["rating": rating]
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
             throw APIError.encodingError(error)
        }
        
        let _: NoReply = try await performRequest(for: request)
    }
}
