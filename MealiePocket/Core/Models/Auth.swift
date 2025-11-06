import Foundation

struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct User: Codable {
    let id: String
    let fullName: String?
    let email: String
    let group: String
    let household: String
    let admin: Bool
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
