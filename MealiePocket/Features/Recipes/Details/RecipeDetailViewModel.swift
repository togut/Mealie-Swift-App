import Foundation
import SwiftUI

@Observable
class RecipeDetailViewModel {
    var recipeDetail: RecipeDetail?
    var isFavorite: Bool = false
    var isLoading = false
    var errorMessage: String?
    var showingAddToPlanSheet = false
    var showingAddToListSheet = false
    var showingEditSheet = false
    var needsRefresh = false
    
    private var recipeSummary: RecipeSummary
    
    init(recipeSummary: RecipeSummary) {
        self.recipeSummary = recipeSummary
        self.isFavorite = recipeSummary.isFavorite
    }
    
    func loadRecipeDetail(slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "error.apiClientOrIDUnavailable"
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
                self.needsRefresh = false
            }
            
        } catch APIError.unauthorized {
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "error.loadingRecipeDetails"
                self.isLoading = false
                self.needsRefresh = false
            }
        }
    }
    
    func setRating(_ rating: Double, slug: String, apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID else {
            errorMessage = "error.apiClientOrIDUnavailable"
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
                self.errorMessage = "error.settingRating"
            }
        }
    }
    
    func toggleFavorite(apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient = apiClient, let userID = userID, let detail = recipeDetail else {
            errorMessage = "error.toggleFavoriteMissingData"
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
                errorMessage = "error.updatingFavorite"
            }
        }
    }
    
    func addToMealPlan(date: Date, mealType: MealType, apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient, let detail = recipeDetail else {
            errorMessage = "error.addToPlanMissingData"
            return
        }
        
        do {
            try await apiClient.addMealPlanEntry(date: date, recipeId: detail.id, entryType: mealType.rawValue)
            await MainActor.run {
                showingAddToPlanSheet = false
            }
        } catch APIError.unauthorized {
        } catch {
            await MainActor.run {
                errorMessage = "error.addingToMealPlan"
            }
        }
    }
    
    // MARK: - Recipe Scaling
    
    var targetServings: Double? = nil
    
    var originalServings: Double? {
        recipeDetail?.recipeServings
    }
    
    var scaleFactor: Double {
        IngredientScaler.scaleFactor(originalServings: originalServings, targetServings: targetServings)
    }
    
    var isScaled: Bool {
        guard let target = targetServings, let original = originalServings else { return false }
        return abs(target - original) > 0.01
    }
    
    var currentServings: Double? {
        targetServings ?? originalServings
    }
    
    func incrementServings() {
        guard let current = currentServings else { return }
        targetServings = current + 1
    }
    
    func decrementServings() {
        guard let current = currentServings, current > 1 else { return }
        targetServings = current - 1
    }
    
    func resetServings() {
        targetServings = nil
    }
    
    func scaledDisplayText(for ingredient: RecipeIngredient) -> String {
        IngredientScaler.displayText(for: ingredient, scaleFactor: scaleFactor)
    }
    
    // MARK: - Add to Shopping List

    enum AddToListStatus: Equatable {
        case idle
        case success
        case failed
    }

    var addToListStatus: AddToListStatus = .idle
    private var lastAddToListParams: (listId: UUID, ingredients: [RecipeIngredient]?)? = nil
    private var toastDismissTask: Task<Void, Never>? = nil

    func addIngredientsToList(listId: UUID, ingredients: [RecipeIngredient]?, apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient, let detail = recipeDetail else { return }

        lastAddToListParams = (listId, ingredients)

        do {
            _ = try await apiClient.addRecipesToShoppingListBulk(
                listId: listId,
                recipeIds: [detail.id],
                scale: scaleFactor,
                ingredients: ingredients
            )
            await MainActor.run {
                withAnimation { addToListStatus = .success }
                scheduleToastDismiss()
            }
        } catch APIError.unauthorized {
            // Handled globally
        } catch {
            await MainActor.run {
                withAnimation { addToListStatus = .failed }
            }
        }
    }

    func retryAddToList(apiClient: MealieAPIClient?) async {
        guard let params = lastAddToListParams else { return }
        await addIngredientsToList(listId: params.listId, ingredients: params.ingredients, apiClient: apiClient)
    }

    @MainActor
    func dismissAddToListStatus() {
        withAnimation { addToListStatus = .idle }
    }

    private func scheduleToastDismiss() {
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.dismissAddToListStatus()
        }
    }

    @MainActor
    func markForRefresh() {
        needsRefresh = true
    }
}
