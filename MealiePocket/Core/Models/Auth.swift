import Foundation

struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct User: Decodable {
    let id: String
}

struct UserRating: Decodable, Hashable {
    let recipeId: UUID
    let isFavorite: Bool
}

struct UserRatingsResponse: Decodable {
    let ratings: [UserRating]
}
