import SwiftUI

struct RecipeListView: View {
    @State private var viewModel = RecipeListViewModel()
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filteredRecipes: [RecipeSummary] {
        if searchText.isEmpty {
            return viewModel.recipes
        } else {
            return viewModel.recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    contentUnavailable(title: "Error", message: errorMessage)
                } else if filteredRecipes.isEmpty && !searchText.isEmpty {
                    contentUnavailable(title: "No Results", message: "No recipes found for \"\(searchText)\".", systemImage: "magnifyingglass")
                } else if viewModel.recipes.isEmpty {
                    contentUnavailable(title: "No Recipes", message: "Your recipe book is empty.", systemImage: "book")
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .task {
                if viewModel.recipes.isEmpty {
                    await viewModel.loadRecipes(apiClient: appState.apiClient)
                }
            }
            .refreshable {
                await viewModel.loadRecipes(apiClient: appState.apiClient)
            }
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipeSummary: recipe)
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCardView(recipe: recipe, baseURL: appState.apiClient?.baseURL)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private func contentUnavailable(title: String, message: String, systemImage: String? = "exclamationmark.triangle") -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage ?? "exclamationmark.triangle")
        } description: {
            Text(message)
        }
    }
}
