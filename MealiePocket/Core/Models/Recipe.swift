import Foundation

struct RecipeSummary: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
    let image: String
    let recipeYield: String?
    let totalTime: String?
    let rating: Double?
    var isFavorite: Bool = false
}

struct PaginatedRecipes: Decodable {
    let items: [RecipeSummary]
    let totalPages: Int
}

struct RecipeDetail: Decodable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let totalTime: String?
    let prepTime: String?
    let cookTime: String?
    let recipeIngredient: [RecipeIngredient]
    let recipeInstructions: [RecipeInstruction]
}

struct RecipeIngredient: Decodable, Identifiable, Hashable {
    let id = UUID()
    let display: String

    enum CodingKeys: String, CodingKey {
        case display
    }
}

struct RecipeInstruction: Decodable, Identifiable, Hashable {
    let id: UUID
    let title: String?
    let summary: String?
    let text: String
}
