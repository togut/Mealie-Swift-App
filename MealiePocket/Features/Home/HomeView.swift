import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    if viewModel.isLoading && viewModel.favoriteRecipes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    } else if !viewModel.favoriteRecipes.isEmpty {
                        Text("Favorites")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        favoritesCarousel
                        
                    } else {
                        ContentUnavailableView("No Favorites", systemImage: "heart.slash", description: Text("Your favorite recipes will appear here."))
                    }
                }
            }
            .navigationTitle("Home")
            .task {
                await viewModel.loadFavorites(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
            .refreshable {
                await viewModel.loadFavorites(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipeSummary: recipe)
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
            .padding(.bottom)
        }
    }
}
