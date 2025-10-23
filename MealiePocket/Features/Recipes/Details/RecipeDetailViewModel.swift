import Foundation

@Observable
class RecipeDetailViewModel {
    var recipeDetail: RecipeDetail?
    var isLoading = false
    var errorMessage: String?

    func loadRecipeDetail(slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "API client or User ID not available."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let detailTask = apiClient.fetchRecipeDetail(slug: slug)
            async let ratingsTask = apiClient.fetchRatings(userID: userID)

            var detail = try await detailTask
            let allUserRatings = try await ratingsTask

            let currentUserRating = allUserRatings.first { $0.recipeId == detail.id }

            detail.userRating = currentUserRating?.rating

            await MainActor.run {
                self.recipeDetail = detail
                self.isLoading = false
            }

        } catch APIError.unauthorized {
             await MainActor.run { isLoading = false }
        } catch {
             await MainActor.run {
                self.errorMessage = "Failed to load recipe details: \(error.localizedDescription)"
                self.isLoading = false
             }
        }
    }
    
    func setRating(_ rating: Double, slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "API client or User ID not available."
            return
        }
        
        let previousRating = recipeDetail?.userRating
        
        await MainActor.run {
             self.recipeDetail?.userRating = rating
        }

        do {
            try await apiClient.setRating(userID: userID, slug: slug, rating: rating)
        } catch APIError.unauthorized {
             await MainActor.run { self.recipeDetail?.userRating = previousRating }
        } catch {
            await MainActor.run {
                self.recipeDetail?.userRating = previousRating
                self.errorMessage = "Failed to set rating: \(error.localizedDescription)"
            }
        }
    }
}
