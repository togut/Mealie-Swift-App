import Foundation

@Observable
class RecipeListViewModel {
    var recipes: [RecipeSummary] = []

    var isLoading = false
    var errorMessage: String?
    
    var sortOption: SortOption = .name
    var sortDirection: SortDirection = .asc
    
    private var paginationSeed: String?
    
    init() {
        if let cachedRecipes = RecipeCache.load(), !cachedRecipes.isEmpty {
            self.recipes = cachedRecipes
        }
    }
    
    func setSortOption(_ newOption: SortOption) {
        sortOption = newOption
        sortDirection = newOption.defaultDirection
    }

    func applySort(apiClient: MealieAPIClient?, userID: String?) async {
        await loadAllRecipes(apiClient: apiClient, userID: userID, isRefresh: true)
    }
    
    func loadInitialRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        if recipes.isEmpty {
            await loadAllRecipes(apiClient: apiClient, userID: userID, isRefresh: false)
        } else {
            await loadAllRecipes(apiClient: apiClient, userID: userID, isRefresh: true)
        }
    }

    private func loadAllRecipes(apiClient: MealieAPIClient?, userID: String?, isRefresh: Bool) async {
        guard let apiClient, let userID else {
            errorMessage = "API client or User ID is not available."
            return
        }

        if !isRefresh && recipes.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        
        if sortOption == .random {
            paginationSeed = UUID().uuidString
        } else {
            paginationSeed = nil
        }
        
        do {
            async let allRecipesResponse = apiClient.fetchAllRecipes(
                orderBy: sortOption.rawValue,
                orderDirection: sortDirection.rawValue,
                paginationSeed: paginationSeed
            )
            async let userRatingsResponse = apiClient.fetchRatings(userID: userID)
            
            var fetchedRecipes = try await allRecipesResponse
            let userRatings = try await userRatingsResponse
            
            let userRatingsDict = Dictionary(uniqueKeysWithValues: userRatings.map { ($0.recipeId, $0) })

            for i in fetchedRecipes.indices {
                if let userRatingData = userRatingsDict[fetchedRecipes[i].id] {
                    fetchedRecipes[i].isFavorite = userRatingData.isFavorite
                    fetchedRecipes[i].userRating = userRatingData.rating
                } else {
                    fetchedRecipes[i].isFavorite = false
                    fetchedRecipes[i].userRating = nil
                }
            }
            
            await MainActor.run {
                self.recipes = fetchedRecipes
                RecipeCache.save(fetchedRecipes)
                self.isLoading = false
            }
            
        } catch APIError.unauthorized {
             await MainActor.run { isLoading = false }
        } catch {
            if recipes.isEmpty {
                await MainActor.run {
                     self.errorMessage = "Failed to load recipes: \(error.localizedDescription)"
                     self.isLoading = false
                }
            } else {
                 print("Failed to refresh recipes: \(error.localizedDescription)")
                 await MainActor.run { isLoading = false }
            }
        }
    }

    func toggleFavorite(for recipeId: UUID, userID: String?, apiClient: MealieAPIClient?) async {
        guard let apiClient, let userID else { return }

        updateFavoriteStatus(for: recipeId, in: &recipes)
        
        guard let recipe = recipes.first(where: { $0.id == recipeId }) else { return }
        
        do {
            if recipe.isFavorite {
                try await apiClient.addFavorite(userID: userID, slug: recipe.slug)
                RecipeCache.save(recipes)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: recipe.slug)
                RecipeCache.save(recipes)
            }
        } catch {
            updateFavoriteStatus(for: recipeId, in: &recipes)
             await MainActor.run {
                 self.errorMessage = "Failed to update favorite status: \(error.localizedDescription)"
             }
        }
    }
    
    private func updateFavoriteStatus(for recipeId: UUID, in list: inout [RecipeSummary]) {
        if let index = list.firstIndex(where: { $0.id == recipeId }) {
            list[index].isFavorite.toggle()
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case name = "name"
    case createdAt = "createdAt"
    case lastMade = "lastMade"
    case updatedAt = "updatedAt"
    case rating = "rating"
    case random = "random"

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .name: "Name"
        case .createdAt: "Date Created"
        case .lastMade: "Last Made"
        case .updatedAt: "Date Updated"
        case .rating: "Overall rating"
        case .random: "Random"
        }
    }
    
    var defaultDirection: SortDirection {
        switch self {
        case .name:
            return .asc
        case .createdAt, .lastMade, .updatedAt, .rating:
            return .desc
        case .random:
            return .asc
        }
    }
}

enum SortDirection: String {
    case asc = "asc"
    case desc = "desc"
}
