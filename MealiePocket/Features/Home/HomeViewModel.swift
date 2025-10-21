import Foundation

@Observable
class HomeViewModel {
    var favoriteRecipes: [RecipeSummary] = []
    var isLoading = false
    var errorMessage: String?
    
    func loadFavorites(apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient else {
            errorMessage = "API client not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.fetchRecipes(
                page: 1,
                orderBy: "name",
                orderDirection: "asc",
                paginationSeed: nil,
                queryFilter: "isFavorite IS true"
            )
            
            var favorites = response.items
            for i in favorites.indices {
                favorites[i].isFavorite = true
            }
            favoriteRecipes = favorites
            
        } catch {
            errorMessage = "Failed to load favorite recipes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
