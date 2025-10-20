import Foundation

struct RecipeSummary: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
    let image: String
    let recipeYield: String?
    let totalTime: String?
    let rating: Double?
}

struct PaginatedRecipes: Decodable {
    let items: [RecipeSummary]
}
