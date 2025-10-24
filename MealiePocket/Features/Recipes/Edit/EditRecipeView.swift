import SwiftUI

struct EditRecipeView: View {
    @State var viewModel: EditRecipeViewModel
    var apiClient: MealieAPIClient?
    
    @Environment(\.dismiss) var dismiss
    @State private var localEditMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
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
                            TextEditor(text: $ingredient.note)
                                .frame(minHeight: 30)
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
