import Foundation

@Observable
class HomeViewModel {
    var favoriteRecipes: [RecipeSummary] = []
    var isLoading = false
    var errorMessage: String?

    var weeklyMeals: [Date: [ReadPlanEntry]] = [:]
    var daysOfWeek: [Date] = []
    var isLoadingWeeklyMeals = false
    var weeklyMealsErrorMessage: String?

    var showingAddRecipeSheet = false
    var dateForAddingRecipe: Date? = nil
    var recipesForSelection: [RecipeSummary] = []
    var isLoadingRecipesForSelection = false
    var isLoadingMoreRecipesForSelection = false
    var searchQueryForSelection = ""
    private var searchTaskForSelection: Task<Void, Never>? = nil
    private var currentPageForSelection = 1
    private var totalPagesForSelection = 1
    var canLoadMoreForSelection: Bool { currentPageForSelection < totalPagesForSelection }

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
                let ratingsDict = Dictionary(uniqueKeysWithValues: favoriteRatings.map { ($0.recipeId, $0) })

                for i in favorites.indices {
                    if let userRatingData = ratingsDict[favorites[i].id] {
                        favorites[i].isFavorite = true
                        favorites[i].userRating = userRatingData.rating
                    }
                }
                
                await MainActor.run { favoriteRecipes = favorites }
            }
        } catch APIError.unauthorized {
             await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load favorite recipes: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run { isLoading = false }
    }

    private func getCurrentWeekDates() -> [Date] {
        let calendar = Calendar.current
        guard let today = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()),
              let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)
        else { return [] }
        
        var dates: [Date] = []
        calendar.enumerateDates(startingAfter: weekInterval.start.addingTimeInterval(-1),
                                matching: DateComponents(hour: 0, minute: 0, second: 0),
                                matchingPolicy: .nextTime) { (date, _, stop) in
            guard let date = date else { return }
            if date < weekInterval.end {
                dates.append(date)
            } else {
                stop = true
            }
        }
        return dates
    }

    func loadHomeData(apiClient: MealieAPIClient?, userID: String?) async {
        async let favoritesTask: () = loadFavorites(apiClient: apiClient, userID: userID)
        async let weeklyMealsTask: () = loadWeeklyMeals(apiClient: apiClient)
        _ = await (favoritesTask, weeklyMealsTask)
    }

    func loadWeeklyMeals(apiClient: MealieAPIClient?) async {
        guard let apiClient = apiClient else {
            await MainActor.run { weeklyMealsErrorMessage = "API client not available." }
            return
        }
        
        await MainActor.run {
            isLoadingWeeklyMeals = true
            weeklyMealsErrorMessage = nil
            self.daysOfWeek = getCurrentWeekDates()
        }

        guard let firstDay = daysOfWeek.first, let lastDay = daysOfWeek.last else {
            await MainActor.run {
                isLoadingWeeklyMeals = false
                weeklyMealsErrorMessage = "Impossible de calculer les dates de la semaine."
            }
            return
        }
        
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }()
        
        let startDateString = dateFormatter.string(from: firstDay)
        guard let dayAfterLast = Calendar.current.date(byAdding: .day, value: 1, to: lastDay) else {
            await MainActor.run {
                isLoadingWeeklyMeals = false
                weeklyMealsErrorMessage = "Impossible de calculer la date de fin pour l'API."
            }
            return
        }
        let endDateString = dateFormatter.string(from: dayAfterLast)
        
        
        do {
            let response = try await apiClient.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString, perPage: 100)
            
            var groupedEntries: [Date: [ReadPlanEntry]] = [:]
            for entry in response.items {
                if let entryDateUTC = dateFormatter.date(from: entry.date) {
                    let entryDateLocalMidnight = Calendar.current.startOfDay(for: entryDateUTC)
                    groupedEntries[entryDateLocalMidnight, default: []].append(entry)
                }
            }
            
            await MainActor.run {
                self.weeklyMeals = groupedEntries
            }
        } catch APIError.unauthorized {
        } catch {
            await MainActor.run {
                weeklyMealsErrorMessage = "Failed to load weekly meals: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run { isLoadingWeeklyMeals = false }
    }

    func presentAddRecipeSheet(apiClient: MealieAPIClient?, for date: Date) {
        guard let apiClient = apiClient else { return }

        dateForAddingRecipe = date
        searchQueryForSelection = ""
        recipesForSelection = []
        currentPageForSelection = 1
        totalPagesForSelection = 1
        isLoadingRecipesForSelection = false
        isLoadingMoreRecipesForSelection = false
        showingAddRecipeSheet = true

        Task { await searchRecipesForSelection(apiClient: apiClient, loadMore: false) }
    }

    func searchRecipesForSelection(apiClient: MealieAPIClient?, loadMore: Bool = false) async {
        guard let apiClient = apiClient else { return }
        
        if !loadMore {
            searchTaskForSelection?.cancel()
            currentPageForSelection = 1
            isLoadingRecipesForSelection = true
            isLoadingMoreRecipesForSelection = false
        } else {
            guard canLoadMoreForSelection, !isLoadingMoreRecipesForSelection else { return }
            isLoadingMoreRecipesForSelection = true
            isLoadingRecipesForSelection = false
        }
        
        searchTaskForSelection = Task {
            do {
                if !loadMore { try await Task.sleep(nanoseconds: 300_000_000) }
                let pageToLoad = loadMore ? currentPageForSelection + 1 : 1
                let response = try await apiClient.fetchRecipes(
                    page: pageToLoad, orderBy: "name", orderDirection: "asc", paginationSeed: nil,
                    queryFilter: searchQueryForSelection.isEmpty ? nil : "name LIKE %\(searchQueryForSelection)%",
                    perPage: 25
                )
                let fetchedRecipes = response.items
                await MainActor.run {
                    if loadMore {
                        self.recipesForSelection.append(contentsOf: fetchedRecipes)
                        self.currentPageForSelection = pageToLoad
                    } else {
                        self.recipesForSelection = fetchedRecipes
                        self.currentPageForSelection = 1
                    }
                    self.totalPagesForSelection = response.totalPages
                    self.isLoadingRecipesForSelection = false
                    self.isLoadingMoreRecipesForSelection = false
                }
            } catch APIError.unauthorized {
                await MainActor.run {
                    isLoadingRecipesForSelection = false
                    isLoadingMoreRecipesForSelection = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    if !loadMore { isLoadingRecipesForSelection = false }
                }
            } catch {
                await MainActor.run {
                    if !loadMore { self.recipesForSelection = [] }
                    self.isLoadingRecipesForSelection = false
                    self.isLoadingMoreRecipesForSelection = false
                }
            }
        }
    }

    func loadMoreRecipesForSelection(apiClient: MealieAPIClient?) async {
        await searchRecipesForSelection(apiClient: apiClient, loadMore: true)
    }

    func addSelectedRecipeToPlan(recipe: RecipeSummary, mealType: String, apiClient: MealieAPIClient?) async {
        guard let date = dateForAddingRecipe, let apiClient = apiClient else {
            print("Erreur: Date ou client API manquant pour ajout depuis Home.")
            return
        }

        await MainActor.run { isLoadingWeeklyMeals = true }
        
        do {
            try await apiClient.addMealPlanEntry(date: date, recipeId: recipe.id, entryType: mealType)

            await loadWeeklyMeals(apiClient: apiClient)
            await MainActor.run {
                showingAddRecipeSheet = false
                isLoadingWeeklyMeals = false
            }
        } catch {
            await MainActor.run {
                print("Erreur lors de l'ajout au planning depuis Home: \(error.localizedDescription)")
                isLoadingWeeklyMeals = false
            }
        }
    }
}
