import SwiftUI

struct RecipeListView: View {
    @State private var viewModel = RecipeListViewModel()
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filteredRecipes: [RecipeSummary] {
        viewModel.recipes.filter { recipe in
            let searchMatch = searchText.isEmpty || recipe.name.localizedCaseInsensitiveContains(searchText)
            return searchMatch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.recipes.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    contentUnavailable(title: "Error", message: errorMessage)
                } else if filteredRecipes.isEmpty && searchText.isEmpty {
                    contentUnavailable(title: "No Results", message: "No recipes match your filter.", systemImage: "magnifyingglass")
                } else if viewModel.recipes.isEmpty {
                    contentUnavailable(title: "No Recipes", message: "Your recipe book is empty.", systemImage: "book")
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    sortMenu
                }
            }
            .task {
                if viewModel.recipes.isEmpty {
                    await viewModel.loadInitialRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
                }
            }
            .refreshable {
                await viewModel.loadInitialRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
            .navigationDestination(for: RecipeSummary.self) { recipe in
                RecipeDetailView(recipeSummary: recipe)
            }
        }
    }
    
    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(filteredRecipes, id: \.id) { recipe in
                    if let index = viewModel.recipes.firstIndex(where: { $0.id == recipe.id }) {
                        let recipeBinding = $viewModel.recipes[index]
                        
                        NavigationLink(value: recipe) {
                            RecipeCardView(recipe: recipeBinding, baseURL: appState.apiClient?.baseURL) {
                                Task {
                                    await viewModel.toggleFavorite(for: recipe.id, userID: appState.currentUserID, apiClient: appState.apiClient)
                                }
                            }
                            .task {
                                if index == viewModel.recipes.count - 1 {
                                    await viewModel.loadMoreRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            
            if viewModel.isLoadingMore {
                ProgressView()
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $viewModel.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            
            if viewModel.sortOption != .random {
                Picker("Direction", selection: $viewModel.sortDirection) {
                    Text("Ascending").tag(SortDirection.asc)
                    Text("Descending").tag(SortDirection.desc)
                }
            }
            
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .onChange(of: viewModel.sortOption) {
            viewModel.setSortOption(viewModel.sortOption)
            Task { await viewModel.applySort(apiClient: appState.apiClient, userID: appState.currentUserID) }
        }
        .onChange(of: viewModel.sortDirection) {
            Task { await viewModel.applySort(apiClient: appState.apiClient, userID: appState.currentUserID) }
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
