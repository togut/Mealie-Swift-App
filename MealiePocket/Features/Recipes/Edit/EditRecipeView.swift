import SwiftUI

struct EditRecipeView: View {
    @State var viewModel: EditRecipeViewModel
    var apiClient: MealieAPIClient?
    
    @Environment(\.dismiss) var dismiss
    @State private var localEditMode: EditMode = .inactive
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(5...)
                    TextField("Yield (e.g., 4 servings)", text: $viewModel.recipeYield)
                }
                
                Section("Times") {
                    TextField("Total Time (e.g., 1h 30m)", text: $viewModel.totalTime)
                    TextField("Prep Time (e.g., 20m)", text: $viewModel.prepTime)
                    TextField("Cook Time (e.g., 1h 10m)", text: $viewModel.performTime)
                }
                
                Section("Ingredients") {
                    List {
                        ForEach($viewModel.ingredients) { $ingredient in
                            if let title = ingredient.title, !title.isEmpty {
                                Text(title).font(.headline).padding(.top, 5)
                            }
                            
                            VStack(alignment: .leading) {
                                HStack(spacing: 12) {
                                    TextField("Qté", value: $ingredient.quantity.bound, formatter: numberFormatter)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 60)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Picker("Unité", selection: $ingredient.unit) {
                                        Text("(optionnel)").tag(nil as RecipeIngredient.IngredientUnitStub?)
                                        ForEach(viewModel.allUnits) { unit in
                                            Text(unit.name).tag(unit as RecipeIngredient.IngredientUnitStub?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .tint(.primary)
                                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                                    
                                    NavigationLink(destination:
                                        FoodSearchView(
                                            selectedFood: $ingredient.food,
                                            searchResults: viewModel.foodSearchResults,
                                            onSearchQueryChanged: { newQuery in
                                                await viewModel.searchFoods(query: newQuery, apiClient: apiClient)
                                            },
                                            onCreateTapped: { foodName in
                                                return await viewModel.createFood(name: foodName, apiClient: apiClient)
                                            }
                                        )
                                    ) {
                                        Text($ingredient.food.wrappedValue?.name ?? "Choisir...")
                                            .foregroundColor($ingredient.food.wrappedValue == nil ? .gray : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                
                                TextEditor(text: $ingredient.note)
                                    .frame(minHeight: 30)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: viewModel.removeIngredient)
                        .onMove(perform: viewModel.moveIngredients)
                    }
                    Button("Add Ingredient", systemImage: "plus") { viewModel.addIngredient() }
                }
                
                Section("Instructions") {
                    List {
                        ForEach($viewModel.instructions) { $instruction in
                            VStack(alignment: .leading) {
                                TextField("Optional Title", text: $instruction.title.bound)
                                    .font(.headline)
                                TextEditor(text: $instruction.text)
                                    .frame(minHeight: 50)
                            }
                        }
                        .onDelete(perform: viewModel.removeInstruction)
                        .onMove(perform: viewModel.moveInstructions)
                    }
                    Button("Add Instruction", systemImage: "plus") { viewModel.addInstruction() }
                }
                
                Section("Settings") {
                    Toggle("Public Recipe", isOn: $viewModel.settings.publicRecipe.bound)
                    Toggle("Show Nutrition", isOn: $viewModel.settings.showNutrition.bound)
                    Toggle("Show Assets", isOn: $viewModel.settings.showAssets.bound)
                    Toggle("Disable Comments", isOn: $viewModel.settings.disableComments.bound)
                    Toggle("Landscape View", isOn: $viewModel.settings.landscapeView.bound)
                    Toggle("Locked", isOn: $viewModel.settings.locked.bound)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if localEditMode.isEditing {
                        Button("Done") {
                            localEditMode = .inactive
                        }
                    } else {
                        Button("Edit") {
                            localEditMode = .active
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                if await viewModel.saveChanges(apiClient: apiClient) {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(viewModel.name.isEmpty)
                    }
                }
            }
            .environment(\.editMode, $localEditMode)
            .onAppear {
                Task {
                    await viewModel.fetchAllUnits(apiClient: apiClient)
                }
            }
        }
    }
}

extension Optional where Wrapped == String {
    var bound: String {
        get { self ?? "" }
        set { self = newValue.isEmpty ? nil : newValue }
    }
}

extension Optional where Wrapped == Bool {
    var bound: Bool {
        get { self ?? false }
        set { self = newValue }
    }
}

extension Optional where Wrapped == Double {
     var bound: Double {
         get { self ?? 0 }
         set { self = newValue }
     }
 }
