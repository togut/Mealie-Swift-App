import Foundation

@Observable
class RecipeListViewModel {
    var recipes: [RecipeSummary] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    
    var sortOption: SortOption = .name
    var sortDirection: SortDirection = .asc
    
    private var currentPage = 1
    private var totalPages = 1
    private var paginationSeed: String?
    
    private var canLoadMore: Bool {
        currentPage < totalPages && !isLoading
    }
    
    func setSortOption(_ newOption: SortOption) {
        sortOption = newOption
        sortDirection = newOption.defaultDirection
    }
    
    func loadInitialRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        currentPage = 1
        totalPages = 1
        
        if sortOption == .random {
            paginationSeed = UUID().uuidString
        } else {
            paginationSeed = nil
        }
        
        await loadRecipes(apiClient: apiClient, userID: userID, initialLoad: true)
    }

    func loadMoreRecipes(apiClient: MealieAPIClient?, userID: String?) async {
        guard canLoadMore else { return }
        currentPage += 1
        await loadRecipes(apiClient: apiClient, userID: userID, initialLoad: false)
    }

    private func loadRecipes(apiClient: MealieAPIClient?, userID: String?, initialLoad: Bool) async {
        guard let apiClient, let userID else {
            errorMessage = "API client or User ID is not available."
            return
        }

        if initialLoad {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        errorMessage = nil
        
        do {
            async let recipesResponse = apiClient.fetchRecipes(
                page: currentPage,
                orderBy: sortOption.rawValue,
                orderDirection: sortDirection.rawValue,
                paginationSeed: paginationSeed
            )
            async let favoritesResponse = apiClient.fetchFavorites(userID: userID)
            
            let fetchedRecipes = try await recipesResponse
            let favorites = try await favoritesResponse
            let favoriteIDs = Set(favorites.map { $0.recipeId })

            var updatedItems = fetchedRecipes.items
            for i in updatedItems.indices {
                if favoriteIDs.contains(updatedItems[i].id) {
                    updatedItems[i].isFavorite = true
                }
            }

            if initialLoad {
                recipes = updatedItems
            } else {
                recipes.append(contentsOf: updatedItems)
            }
            totalPages = fetchedRecipes.totalPages
            
        } catch {
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
        }
        
        if initialLoad {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }
    
    func toggleFavorite(for recipeId: UUID, userID: String?, apiClient: MealieAPIClient?) async {
        guard let apiClient,
              let userID,
              let index = recipes.firstIndex(where: { $0.id == recipeId }) else { return }

        let recipe = recipes[index]
        let newFavoriteState = !recipe.isFavorite
        
        recipes[index].isFavorite = newFavoriteState
        
        do {
            if newFavoriteState {
                try await apiClient.addFavorite(userID: userID, slug: recipe.slug)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: recipe.slug)
            }
        } catch {
            recipes[index].isFavorite = !newFavoriteState
            errorMessage = "Failed to update favorite status"
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
        case .rating: "Rating"
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
