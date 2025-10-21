import Foundation

@Observable
class HomeViewModel {
    var favoriteRecipes: [RecipeSummary] = []
    var isLoading = false
    var errorMessage: String?
    
    func loadFavorites(apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient, let userID else {
            errorMessage = "API client or User ID not available."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let favoriteRatings = try await apiClient.fetchFavorites(userID: userID)
            let favoriteIDs = favoriteRatings.map { $0.recipeId.uuidString }
            
            if favoriteIDs.isEmpty {
                await MainActor.run { favoriteRecipes = [] }
            } else {
                let filter = "id IN [\"\(favoriteIDs.joined(separator: "\",\""))\"]"
                let response = try await apiClient.fetchRecipes(
                    page: 1,
                    orderBy: "name",
                    orderDirection: "asc",
                    paginationSeed: nil,
                    queryFilter: filter,
                    perPage: 1000
                )
                
                var favorites = response.items
                for i in favorites.indices {
                    favorites[i].isFavorite = true
                }
                
                await MainActor.run { favoriteRecipes = favorites }
            }
        } catch {
            guard !(error is CancellationError) && (error as? URLError)?.code != .cancelled else {
                return
            }
            await MainActor.run {
                errorMessage = "Failed to load favorite recipes: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run { isLoading = false }
    }
}
