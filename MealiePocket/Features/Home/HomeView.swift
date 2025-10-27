import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var mealPlannerViewModel = MealPlannerViewModel()
    @Environment(AppState.self) private var appState

    @Binding var selectedTab: Int
    let plannerTabIndex = 2

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Section {
                        if viewModel.isLoading && viewModel.favoriteRecipes.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        } else if !viewModel.favoriteRecipes.isEmpty {
                            Text("Favoris")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            favoritesCarousel
                        } else {
                            ContentUnavailableView("Aucun Favori", systemImage: "heart.slash", description: Text("Vos recettes favorites apparaîtront ici."))
                                .padding(.vertical, 40)
                        }
                    }

                    Section {
                        if let weeklyError = viewModel.weeklyMealsErrorMessage {
                            Text(weeklyError)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        if !viewModel.isLoadingWeeklyMeals || !viewModel.weeklyMeals.isEmpty {
                            Text("Cette semaine")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            weeklyMealsCarousel
                        } else if viewModel.isLoadingWeeklyMeals {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .task {
                await viewModel.loadHomeData(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
            .refreshable {
                await viewModel.loadHomeData(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipeSummary: recipe)
            }
            .sheet(isPresented: $viewModel.showingAddRecipeSheet) {
                if let date = viewModel.dateForAddingRecipe {
                    SelectRecipeForHomeSheetView(viewModel: viewModel, date: date, apiClient: appState.apiClient)
                } else {
                    Text("Erreur: Date non sélectionnée.")
                }
            }
            .onChange(of: viewModel.searchQueryForSelection) { _, _ in
                Task { await viewModel.searchRecipesForSelection(apiClient: appState.apiClient, loadMore: false) }
            }
        }
    }

    private var favoritesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach($viewModel.favoriteRecipes) { $recipe in
                    NavigationLink(value: recipe) {
                        FavoriteCardView(recipe: $recipe, baseURL: appState.apiClient?.baseURL, showFavoriteButton: false)
                            .frame(width: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var weeklyMealsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.daysOfWeek, id: \.self) { day in
                    MealDayCardView(
                        date: day,
                        entries: viewModel.weeklyMeals[day] ?? [],
                        baseURL: appState.apiClient?.baseURL,
                        onAddRecipeTapped: { selectedDate in
                            viewModel.presentAddRecipeSheet(apiClient: appState.apiClient, for: selectedDate)
                        },
                        selectedTab: $selectedTab
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}
