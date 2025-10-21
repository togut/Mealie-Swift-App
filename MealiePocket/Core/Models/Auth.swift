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
    let id: UUID
    let recipeId: UUID
    let userId: UUID
    let rating: Double?
    let isFavorite: Bool
}

struct UserRatingsResponse: Decodable {
    let ratings: [UserRating]
}
