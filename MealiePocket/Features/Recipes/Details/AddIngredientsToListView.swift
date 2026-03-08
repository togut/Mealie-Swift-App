import SwiftUI

struct AddIngredientsToListView: View {
    let ingredients: [RecipeIngredient]
    let scaleFactor: Double
    let apiClient: MealieAPIClient
    let onAdd: (UUID, [RecipeIngredient]?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var step: Step = .selectIngredients
    @State private var shoppingLists: [ShoppingListSummary] = []
    @State private var isLoadingLists = false
    @State private var errorMessage: String? = nil

    private enum Step { case selectIngredients, selectList }

    init(ingredients: [RecipeIngredient], scaleFactor: Double = 1.0, apiClient: MealieAPIClient, onAdd: @escaping (UUID, [RecipeIngredient]?) -> Void) {
        self.ingredients = ingredients
        self.scaleFactor = scaleFactor
        self.apiClient = apiClient
        self.onAdd = onAdd
        _selectedIDs = State(initialValue: Set(ingredients.map(\.id)))
    }

    private var selectedCount: Int { selectedIDs.count }
    private var allSelected: Bool { selectedCount == ingredients.count }
    private var noneSelected: Bool { selectedCount == 0 }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selectIngredients:
                    ingredientSelectionView
                case .selectList:
                    listSelectionView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if step == .selectList {
                            step = .selectIngredients
                        } else {
                            dismiss()
                        }
                    } label: {
                        if step == .selectList {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        } else {
                            Text("Cancel")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step == .selectIngredients {
                        Button("Next") { step = .selectList }
                            .fontWeight(.semibold)
                            .disabled(noneSelected)
                    }
                }
            }
        }
    }

    private var ingredientSelectionView: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(ingredients) { ingredient in
                        let isSelected = selectedIDs.contains(ingredient.id)
                        Button {
                            toggleIngredient(ingredient.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                    .font(.title3)
                                Text(displayText(for: ingredient))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("addToList.selectIngredients")
                        Spacer()
                        Button {
                            if allSelected {
                                selectedIDs.removeAll()
                            } else {
                                selectedIDs = Set(ingredients.map(\.id))
                            }
                        } label: {
                            Text(allSelected ? LocalizedStringKey("addToList.deselectAll") : LocalizedStringKey("addToList.selectAll"))
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)

            HStack {
                Text("\(selectedCount) / \(ingredients.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                if scaleFactor != 1.0 {
                    Label("addToList.scaled", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .navigationTitle("addToList.title")
    }

    private var listSelectionView: some View {
        VStack {
            if isLoadingLists {
                ProgressView("addToList.loadingLists")
                Spacer()
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(LocalizedStringKey(error))
                )
            } else if shoppingLists.isEmpty {
                ContentUnavailableView(
                    "addToList.noListsFound",
                    systemImage: "list.bullet.clipboard",
                    description: Text("addToList.createListHint")
                )
            } else {
                List(shoppingLists) { list in
                    Button {
                        let selected: [RecipeIngredient]? = allSelected
                            ? nil
                            : ingredients.filter { selectedIDs.contains($0.id) }
                        onAdd(list.id, selected)
                        dismiss()
                    } label: {
                        HStack {
                            if let name = list.name, !name.isEmpty {
                                Text(name)
                            } else {
                                Text("Untitled List")
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("addToList.selectList")
        .task {
            if shoppingLists.isEmpty { await loadShoppingLists() }
        }
    }

    private func toggleIngredient(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func displayText(for ingredient: RecipeIngredient) -> String {
        IngredientScaler.displayText(for: ingredient, scaleFactor: scaleFactor)
    }

    private func loadShoppingLists() async {
        isLoadingLists = true
        errorMessage = nil
        do {
            let response = try await apiClient.fetchShoppingLists(page: 1, perPage: 500)
            await MainActor.run {
                shoppingLists = response.items
                isLoadingLists = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "error.loadingShoppingLists"
                isLoadingLists = false
            }
        }
    }
}
