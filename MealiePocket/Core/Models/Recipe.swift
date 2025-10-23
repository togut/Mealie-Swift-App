import Foundation

struct RecipeSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
    let recipeYield: String?
    let totalTime: String?
    let rating: Double?
    var userRating: Double?
    var isFavorite: Bool

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, recipeYield, totalTime, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        recipeYield = try container.decodeIfPresent(String.self, forKey: .recipeYield)
        totalTime = try container.decodeIfPresent(String.self, forKey: .totalTime)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        userRating = nil
        isFavorite = false
    }

    init(id: UUID, name: String, slug: String, recipeYield: String?, totalTime: String?, rating: Double?, userRating: Double?, isFavorite: Bool) {
        self.id = id
        self.name = name
        self.slug = slug
        self.recipeYield = recipeYield
        self.totalTime = totalTime
        self.rating = rating
        self.userRating = userRating
        self.isFavorite = isFavorite
    }
    
     func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }

     static func == (lhs: RecipeSummary, rhs: RecipeSummary) -> Bool {
         lhs.id == rhs.id &&
         lhs.name == rhs.name &&
         lhs.slug == rhs.slug &&
         lhs.rating == rhs.rating &&
         lhs.userRating == rhs.userRating &&
         lhs.isFavorite == rhs.isFavorite
     }
}

struct PaginatedRecipes: Decodable {
    let items: [RecipeSummary]
    let totalPages: Int
}

struct RecipeDetail: Decodable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let rating: Double?
    var userRating: Double?
    let totalTime: String?
    let prepTime: String?
    let cookTime: String?
    let recipeServings: Double?
    let recipeYield: String?
    let recipeIngredient: [RecipeIngredient]
    let recipeInstructions: [RecipeInstruction]
    
    private enum CodingKeys: String, CodingKey {
         case id, name, description, rating, totalTime, prepTime, cookTime, recipeServings, recipeYield, recipeIngredient, recipeInstructions
     }
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
