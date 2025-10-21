import Foundation

@Observable
class RecipeListViewModel {
    var recipes: [RecipeSummary] = []
    var allFavorites: [RecipeSummary] = []
    
    var isLoading = false
    var isLoadingMore = false
    var isLoadingFavorites = false
    var errorMessage: String?
    
    var sortOption: SortOption = .name
    var sortDirection: SortDirection = .asc
    var showOnlyFavorites = false
    
    private var currentPage = 1
    private var totalPages = 1
    private var paginationSeed: String?
    
    private var canLoadMore: Bool {
        currentPage < totalPages && !isLoading && !showOnlyFavorites
    }
    
    func setSortOption(_ newOption: SortOption) {
        sortOption = newOption
        sortDirection = newOption.defaultDirection
    }
    
    func applySort(apiClient: MealieAPIClient?, userID: String?) async {
        if showOnlyFavorites {
            await fetchAllFavorites(apiClient: apiClient, userID: userID)
        } else {
            await loadInitialRecipes(apiClient: apiClient, userID: userID)
        }
    }
    
    func toggleFavoritesFilter(apiClient: MealieAPIClient?, userID: String?) async {
        showOnlyFavorites.toggle()
        
        if showOnlyFavorites && allFavorites.isEmpty {
            await fetchAllFavorites(apiClient: apiClient, userID: userID)
        }
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

        if initialLoad { isLoading = true } else { isLoadingMore = true }
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

            if initialLoad { recipes = updatedItems } else { recipes.append(contentsOf: updatedItems) }
            totalPages = fetchedRecipes.totalPages
            
        } catch is CancellationError {
        } catch {
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
        }
        
        if initialLoad { isLoading = false } else { isLoadingMore = false }
    }
    
    private func fetchAllFavorites(apiClient: MealieAPIClient?, userID: String?) async {
        guard let apiClient, let userID else { return }
        
        isLoadingFavorites = true
        
        do {
            let favoriteRatings = try await apiClient.fetchFavorites(userID: userID)
            let favoriteIDs = favoriteRatings.map { $0.recipeId.uuidString }
            
            if !favoriteIDs.isEmpty {
                let filter = "id IN [\"\(favoriteIDs.joined(separator: "\",\""))\"]"
                let response = try await apiClient.fetchRecipes(
                    page: 1,
                    orderBy: sortOption.rawValue,
                    orderDirection: sortDirection.rawValue,
                    paginationSeed: paginationSeed,
                    queryFilter: filter,
                    perPage: 1000
                )
                
                var favorites = response.items
                for i in favorites.indices { favorites[i].isFavorite = true }
                
                allFavorites = favorites
            } else {
                allFavorites = []
            }
        } catch is CancellationError {
            // Ignorer l'erreur d'annulation.
        } catch {
            errorMessage = "Failed to load all favorite recipes."
        }
        
        isLoadingFavorites = false
    }
    
    func toggleFavorite(for recipeId: UUID, userID: String?, apiClient: MealieAPIClient?) async {
        guard let apiClient, let userID else { return }

        updateFavoriteStatus(for: recipeId, in: &recipes)
        updateFavoriteStatus(for: recipeId, in: &allFavorites)

        guard let recipe = recipes.first(where: { $0.id == recipeId }) ?? allFavorites.first(where: { $0.id == recipeId }) else { return }
        
        do {
            if recipe.isFavorite {
                try await apiClient.addFavorite(userID: userID, slug: recipe.slug)
            } else {
                try await apiClient.removeFavorite(userID: userID, slug: recipe.slug)
            }
            if !recipe.isFavorite {
                allFavorites.removeAll { $0.id == recipeId }
            }
        } catch {
            updateFavoriteStatus(for: recipeId, in: &recipes)
            updateFavoriteStatus(for: recipeId, in: &allFavorites)
            errorMessage = "Failed to update favorite status"
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
