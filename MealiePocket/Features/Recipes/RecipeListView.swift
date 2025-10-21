import SwiftUI

struct RecipeListView: View {
    @State private var viewModel = RecipeListViewModel()
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    private var filteredRecipeIndices: [Int] {
        let sourceArray = viewModel.showOnlyFavorites ? viewModel.allFavorites : viewModel.recipes
        return sourceArray.indices.filter { index in
            let recipe = sourceArray[index]
            return searchText.isEmpty || recipe.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading || viewModel.isLoadingFavorites {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    contentUnavailable(title: "Error", message: errorMessage)
                } else if filteredRecipeIndices.isEmpty && (viewModel.showOnlyFavorites || !searchText.isEmpty) {
                    contentUnavailable(title: "No Results", message: "No recipes match your filter.", systemImage: "magnifyingglass")
                } else if viewModel.recipes.isEmpty && !viewModel.showOnlyFavorites {
                    contentUnavailable(title: "No Recipes", message: "Your recipe book is empty.", systemImage: "book")
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    favoritesFilterButton
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
                if viewModel.showOnlyFavorites {
                    recipeGridContent(for: $viewModel.allFavorites)
                } else {
                    recipeGridContent(for: $viewModel.recipes)
                }
            }
            .padding()
            
            if viewModel.isLoadingMore && !viewModel.showOnlyFavorites {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func recipeGridContent(for recipeListBinding: Binding<[RecipeSummary]>) -> some View {
        let filteredIndices = recipeListBinding.wrappedValue.indices.filter { index in
            searchText.isEmpty || recipeListBinding.wrappedValue[index].name.localizedCaseInsensitiveContains(searchText)
        }
        
        ForEach(filteredIndices, id: \.self) { index in
            let recipeBinding = recipeListBinding[index]
            
            NavigationLink(value: recipeBinding.wrappedValue) {
                RecipeCardView(recipe: recipeBinding, baseURL: appState.apiClient?.baseURL) {
                    Task {
                        await viewModel.toggleFavorite(for: recipeBinding.wrappedValue.id, userID: appState.currentUserID, apiClient: appState.apiClient)
                    }
                }
                .task {
                    if !viewModel.showOnlyFavorites && index == viewModel.recipes.count - 1 {
                        await viewModel.loadMoreRecipes(apiClient: appState.apiClient, userID: appState.currentUserID)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private var favoritesFilterButton: some View {
        Button(action: {
            Task {
                await viewModel.toggleFavoritesFilter(apiClient: appState.apiClient, userID: appState.currentUserID)
            }
        }) {
            Image(systemName: viewModel.showOnlyFavorites ? "heart.fill" : "heart")
                .foregroundColor(viewModel.showOnlyFavorites ? .red : .primary)
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
