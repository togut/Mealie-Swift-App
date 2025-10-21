//
//  HomeViewModel.swift
//  MealiePocket
//
//  Created by Loriage on 21/10/2025.
//


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
                // Créer une chaîne de filtre pour la requête API
                let filter = "id IN [\"\(favoriteIDs.joined(separator: "\",\""))\"]"
                
                // Récupérer les détails complets des recettes favorites
                let response = try await apiClient.fetchRecipes(
                    page: 1,
                    orderBy: "name",
                    orderDirection: "asc",
                    paginationSeed: nil,
                    queryFilter: filter
                )
                
                var favorites = response.items
                // Marquer toutes les recettes récupérées comme favorites
                for i in favorites.indices {
                    favorites[i].isFavorite = true
                }
                
                await MainActor.run { favoriteRecipes = favorites }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load favorite recipes: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run { isLoading = false }
    }
}
