import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) var dismiss

    @State private var searchQuery = ""
    @State private var isCreating = false

    @Binding var selectedFood: RecipeIngredient.IngredientFoodStub?

    let searchResults: [RecipeIngredient.IngredientFoodStub]
    let onSearchQueryChanged: (String) async -> Void

    let onCreateTapped: (String) async -> RecipeIngredient.IngredientFoodStub?
    
    var body: some View {
        List {
            if !searchQuery.isEmpty && !isCreating {
                Section {
                    Button(action: {
                        Task {
                            isCreating = true
                            if let newFood = await onCreateTapped(searchQuery) {
                                self.selectedFood = newFood
                                dismiss()
                            }
                            isCreating = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Créer l'aliment \"\(searchQuery)\"")
                        }
                    }
                    .foregroundColor(.accentColor)
                }
            }

            if isCreating {
                Section {
                    HStack {
                        ProgressView()
                        Text("Création en cours...")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Résultats de la recherche")) {
                if searchResults.isEmpty && !searchQuery.isEmpty && !isCreating {
                    Text("Aucun résultat pour \"\(searchQuery)\"")
                        .foregroundStyle(.secondary)
                }

                ForEach(searchResults) { food in
                    Button(food.name) {
                        self.selectedFood = food
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("Rechercher un aliment")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "Tapez pour rechercher...")
        .onChange(of: searchQuery) { _, newValue in
            Task {
                await onSearchQueryChanged(newValue)
            }
        }
        .onDisappear {
            Task { await onSearchQueryChanged("") }
        }
    }
}
