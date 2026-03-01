import SwiftUI

struct AddShoppingItemView: View {
    @Bindable var viewModel: ShoppingListDetailViewModel
    @Environment(\.dismiss) var dismiss
    @State private var foodSearchText = ""
    @State private var justNoteOnly = true

    private var filteredFoods: [RecipeIngredient.IngredientFoodStub] {
        let query = foodSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.availableFoods }
        return viewModel.availableFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Just note", isOn: $justNoteOnly)
                }

                Section {
                    TextField("Name or Note", text: $viewModel.newItemNote)
                }

                if !justNoteOnly {
                    Section {
                        TextField("Search food", text: $foodSearchText)

                        Picker("Food", selection: Binding<String?>(
                            get: { viewModel.selectedFoodIdForNewItem },
                            set: { viewModel.selectedFoodIdForNewItem = $0 }
                        )) {
                            Text("None").tag(nil as String?)
                            ForEach(filteredFoods, id: \.id) { food in
                                Text(food.name).tag(Optional(food.id))
                            }
                        }

                        if viewModel.isLoadingFoods {
                            ProgressView()
                        }

                        if !viewModel.isLoadingFoods && filteredFoods.isEmpty {
                            Text("No foods found")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Quantity", text: $viewModel.newItemQuantityInput)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.newItemQuantityInput) { _, _ in
                                viewModel.syncQuantityFromInput()
                            }
                        Stepper(
                            "",
                            value: Binding(
                                get: { Int(max(1, viewModel.newItemQuantity.rounded())) },
                                set: { viewModel.setNewItemQuantityFromStepper($0) }
                            ),
                            in: 1...500,
                            step: 1
                        )
                        .labelsHidden()
                    }

                    Picker("Unit", selection: Binding<String?>(
                        get: { viewModel.selectedUnitIdForNewItem },
                        set: { viewModel.selectedUnitIdForNewItem = $0 }
                    )) {
                        Text("None").tag(nil as String?)
                        ForEach(viewModel.availableUnits, id: \.id) { unit in
                            Text(unit.name).tag(Optional(unit.id))
                        }
                    }

                    if viewModel.isLoadingUnits {
                        ProgressView()
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle(viewModel.addMultipleMode ? "Add Multiple Items" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        viewModel.resetNewItemFields()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button(viewModel.addMultipleMode ? "Add next" : "Add") {
                            Task {
                                await viewModel.addItem(closeSheetAfterSave: !viewModel.addMultipleMode)
                            }
                        }
                        .disabled({
                            let hasNote = !viewModel.newItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            let hasFood = !justNoteOnly && viewModel.selectedFoodIdForNewItem != nil
                            return !hasNote && !hasFood
                        }())
                    }
                }
            }
            .task {
                await viewModel.loadUnitsForNewItemIfNeeded()
            }
            .onChange(of: justNoteOnly) { _, isOn in
                if isOn {
                    viewModel.selectedFoodIdForNewItem = nil
                    foodSearchText = ""
                } else {
                    Task {
                        await viewModel.loadFoodsForItemIfNeeded()
                    }
                }
            }
        }
    }
}

struct EditShoppingItemView: View {
    @Bindable var viewModel: ShoppingListDetailViewModel
    @Environment(\.dismiss) var dismiss
    @State private var foodSearchText = ""
    @State private var justNoteOnly = true

    private var filteredFoods: [RecipeIngredient.IngredientFoodStub] {
        let query = foodSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.availableFoods }
        return viewModel.availableFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Just note", isOn: $justNoteOnly)
                }

                Section {
                    TextField("Name or Note", text: $viewModel.editItemNote)
                }

                if !justNoteOnly {
                    Section {
                        TextField("Search food", text: $foodSearchText)

                        Picker("Food", selection: Binding<String?>(
                            get: { viewModel.selectedFoodIdForEditItem },
                            set: { viewModel.selectedFoodIdForEditItem = $0 }
                        )) {
                            Text("None").tag(nil as String?)
                            ForEach(filteredFoods, id: \.id) { food in
                                Text(food.name).tag(Optional(food.id))
                            }
                        }

                        if viewModel.isLoadingFoods {
                            ProgressView()
                        }

                        if !viewModel.isLoadingFoods && filteredFoods.isEmpty {
                            Text("No foods found")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("Quantity", text: $viewModel.editItemQuantityInput)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.editItemQuantityInput) { _, _ in
                                viewModel.syncEditQuantityFromInput()
                            }

                        Stepper(
                            "",
                            value: Binding(
                                get: { Int(max(1, viewModel.editItemQuantity.rounded())) },
                                set: { viewModel.setEditItemQuantityFromStepper($0) }
                            ),
                            in: 1...500,
                            step: 1
                        )
                        .labelsHidden()
                    }

                    Picker("Unit", selection: Binding<String?>(
                        get: { viewModel.selectedUnitIdForEditItem },
                        set: { viewModel.selectedUnitIdForEditItem = $0 }
                    )) {
                        Text("None").tag(nil as String?)
                        ForEach(viewModel.availableUnits, id: \.id) { unit in
                            Text(unit.name).tag(Optional(unit.id))
                        }
                    }

                    if viewModel.isLoadingUnits {
                        ProgressView()
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                await viewModel.saveEditedItem()
                            }
                        }
                        .disabled({
                            let hasNote = !viewModel.editItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            let hasFood = !justNoteOnly && viewModel.selectedFoodIdForEditItem != nil
                            return !hasNote && !hasFood
                        }())
                    }
                }
            }
            .task {
                await viewModel.loadUnitsForNewItemIfNeeded()
                justNoteOnly = (viewModel.selectedFoodIdForEditItem == nil)
                if !justNoteOnly {
                    await viewModel.loadFoodsForItemIfNeeded()
                }
            }
            .onChange(of: justNoteOnly) { _, isOn in
                if isOn {
                    viewModel.selectedFoodIdForEditItem = nil
                    foodSearchText = ""
                } else {
                    Task {
                        await viewModel.loadFoodsForItemIfNeeded()
                    }
                }
            }
        }
    }
}
