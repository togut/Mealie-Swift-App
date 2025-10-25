import Foundation
import SwiftUI

@Observable
class RecipeDetailViewModel {
    var recipeDetail: RecipeDetail?
    var isFavorite: Bool = false
    var isLoading = false
    var errorMessage: String?
    var showingAddToPlanSheet = false
    var showingEditSheet = false
    var needsRefresh = false
    
    private var recipeSummary: RecipeSummary
    
    init(recipeSummary: RecipeSummary) {
        self.recipeSummary = recipeSummary
        self.isFavorite = recipeSummary.isFavorite
    }
    
    func loadRecipeDetail(slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "API client or User ID not available."
            isLoading = false
            return
        }
        
        if !needsRefresh {
            isLoading = true
        }
        errorMessage = nil
        needsRefresh = false
        
        do {
            async let detailTask = apiClient.fetchRecipeDetail(slug: slug)
            async let ratingsTask = apiClient.fetchRatings(userID: userID)
            
            var detail = try await detailTask
            let allUserRatings = try await ratingsTask
            
            let currentUserRatingData = allUserRatings.first { $0.recipeId == detail.id }
            let currentFavoriteStatus = currentUserRatingData?.isFavorite ?? false
            
            detail.userRating = currentUserRatingData?.rating
            
            await MainActor.run {
                self.recipeDetail = detail
                self.isFavorite = currentFavoriteStatus
                self.isLoading = false
            }
            
        } catch APIError.unauthorized {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                if self.recipeDetail == nil {
                    self.errorMessage = "Failed to load recipe details: \(error.localizedDescription)"
                } else {
                    self.errorMessage = "Failed to refresh details: \(error.localizedDescription)"
                }
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
    
    func toggleFavorite(apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID, let detail = recipeDetail else {
            errorMessage = "Cannot toggle favorite: Missing data."
            return
        }
        
        let slug = detail.slug
        let originalFavoriteStatus = isFavorite
        
        await MainActor.run {
            isFavorite.toggle()
        }
        
        do {
            if isFavorite {
                try await apiClient.addFavorite(userID: userID, slug: slug)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: slug)
            }
        } catch APIError.unauthorized {
            await MainActor.run { isFavorite = originalFavoriteStatus }
        } catch {
            await MainActor.run {
                isFavorite = originalFavoriteStatus
                errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
            }
        }
    }
    
    func addToMealPlan(date: Date, mealType: String, apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient, let detail = recipeDetail else {
            errorMessage = "Cannot add to plan: Missing data."
            return
        }
        
        do {
            try await apiClient.addMealPlanEntry(date: date, recipeId: detail.id, entryType: mealType)
            print("Recette ajoutée au planning pour le \(date) - \(mealType)")
            await MainActor.run {
                showingAddToPlanSheet = false
            }
        } catch APIError.unauthorized {
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add to meal plan: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    func markForRefresh() {
        needsRefresh = true
    }
}
