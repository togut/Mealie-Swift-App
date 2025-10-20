import Foundation

@Observable
class RecipeListViewModel {
    var recipes: [RecipeSummary] = []
    var isLoading = false
    var errorMessage: String?

    func loadRecipes(apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient else {
            errorMessage = "API client is not available."
            return
        }

        isLoading = true
        errorMessage = nil
        
        do {
            recipes = try await apiClient.fetchAllRecipes()
        } catch {
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
