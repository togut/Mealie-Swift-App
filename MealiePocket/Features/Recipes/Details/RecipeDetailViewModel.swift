import Foundation

@Observable
class RecipeDetailViewModel {
    var recipeDetail: RecipeDetail?
    var isLoading = false
    var errorMessage: String?

    func loadRecipeDetail(slug: String, apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient else {
            errorMessage = "API client not available."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            recipeDetail = try await apiClient.fetchRecipeDetail(slug: slug)
        } catch {
            errorMessage = "Failed to load recipe details: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func setRating(_ rating: Double, slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "API client or User ID not available."
            return
        }
        
        do {
            try await apiClient.setRating(userID: userID, slug: slug, rating: rating)
            recipeDetail?.rating = rating
        } catch {
            errorMessage = "Failed to set rating: \(error.localizedDescription)"
        }
    }
}
