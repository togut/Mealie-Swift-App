import Foundation

struct RecipeSummary: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slug: String
    let recipeYield: String?
    let totalTime: String?
    let rating: Double?
    var isFavorite: Bool // Cette propriété sera gérée manuellement

    // 1. Définir les clés qui existent dans le JSON de l'API
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, recipeYield, totalTime, rating
        // Notez que 'isFavorite' et 'image' ne sont volontairement pas ici
    }

    // 2. Créer un initialiseur personnalisé pour le décodage
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Décoder toutes les valeurs venant de l'API
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        recipeYield = try container.decodeIfPresent(String.self, forKey: .recipeYield)
        totalTime = try container.decodeIfPresent(String.self, forKey: .totalTime)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        
        // 3. Initialiser notre propriété locale à sa valeur par défaut
        isFavorite = false
    }
}

struct PaginatedRecipes: Decodable {
    let items: [RecipeSummary]
    let totalPages: Int // Assurez-vous que ce champ est bien dans votre modèle
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
