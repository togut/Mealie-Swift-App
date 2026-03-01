import Foundation

@Observable
class ShoppingListDetailViewModel {
    var shoppingListDetail: ShoppingListDetail?
    var recipeNameMap: [UUID: String] = [:]
    var isLoading = false
    var isLoadingBulkUpdate = false
    var isLoadingImport = false
    var errorMessage: String?

    var showingAddItemSheet = false
    var showingEditItemSheet = false
    var addMultipleMode = false
    var newItemNote = ""
    var newItemQuantity: Double = 1.0
    var newItemQuantityInput = "1"
    var editingItemId: UUID?
    var editItemNote = ""
    var editItemQuantity: Double = 1.0
    var editItemQuantityInput = "1"
    var availableFoods: [RecipeIngredient.IngredientFoodStub] = []
    var selectedFoodIdForNewItem: String?
    var selectedFoodIdForEditItem: String?
    var isLoadingFoods = false
    var availableUnits: [RecipeIngredient.IngredientUnitStub] = []
    var selectedUnitIdForNewItem: String?
    var selectedUnitIdForEditItem: String?
    var isLoadingUnits = false

    var showingDateRangePicker = false
    var dateRangeStart = Date()
    var dateRangeEnd = Date()

    private let listSummary: ShoppingListSummary
    private var apiClient: MealieAPIClient?
    
    var hasUncheckedItems: Bool {
        shoppingListDetail?.listItems.contains { !$0.checked } ?? false
    }
    
    init(listSummary: ShoppingListSummary) {
        self.listSummary = listSummary
        self.shoppingListDetail = ShoppingListDetail(
            id: listSummary.id,
            name: listSummary.name,
            createdAt: listSummary.createdAt,
            updatedAt: listSummary.updatedAt,
            groupId: listSummary.groupId,
            userId: listSummary.userId,
            householdId: listSummary.householdId,
            listItems: [],
            recipeReferences: []
        )
        
        if let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) {
            self.dateRangeStart = weekInterval.start
            self.dateRangeEnd = weekInterval.end > weekInterval.start ? Calendar.current.date(byAdding: .day, value: -1, to: weekInterval.end)! : weekInterval.start
        }
    }
    
    @MainActor
    func loadListDetails(apiClient: MealieAPIClient?) async {
        self.apiClient = apiClient
        guard let apiClient else {
            errorMessage = "API Client not available."
            return
        }
        guard shoppingListDetail != nil else {
            errorMessage = "Shopping list not initialized."
            return
        }
        
        if !isLoadingImport {
            isLoading = true
        }
        errorMessage = nil
        recipeNameMap = [:]
        
        do {
            let fullDetails = try await apiClient.fetchShoppingListDetail(listId: listSummary.id)
            var items = fullDetails.listItems
            items.sort { !$0.checked && $1.checked }
            
            var nameMap: [UUID: String] = [:]
            if let topLevelRefs = fullDetails.recipeReferences {
                for ref in topLevelRefs {
                    if let recipe = ref.recipe {
                        nameMap[ref.recipeId] = recipe.name
                    }
                }
            }
            self.recipeNameMap = nameMap
            
            self.shoppingListDetail = ShoppingListDetail(
                id: fullDetails.id,
                name: fullDetails.name,
                createdAt: fullDetails.createdAt,
                updatedAt: fullDetails.updatedAt,
                groupId: fullDetails.groupId,
                userId: fullDetails.userId,
                householdId: fullDetails.householdId,
                listItems: items,
                recipeReferences: fullDetails.recipeReferences
            )
        } catch APIError.unauthorized {
            // Session expired — handled by AppState
        } catch {
            errorMessage = "Failed to load list details: \(error.localizedDescription)"
        }
        
        isLoading = false
        isLoadingImport = false
    }
    
    @MainActor
    func addItem(closeSheetAfterSave: Bool = true) async {
        guard let apiClient, let listId = shoppingListDetail?.id else {
            errorMessage = "Cannot add item: API client or List ID missing."
            return
        }

        syncQuantityFromInput()

        let trimmedNote = newItemNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty || selectedFoodIdForNewItem != nil else {
            errorMessage = "Item name or food is required."
            return
        }
        guard newItemQuantity > 0 else {
            errorMessage = "Quantity must be greater than 0."
            return
        }

        let note = trimmedNote
        let quantity = newItemQuantity
        let foodIdForRequest = selectedFoodIdForNewItem
        let unitIdForRequest = selectedUnitIdForNewItem
        let optimisticFoodId = foodIdForRequest.flatMap { UUID(uuidString: $0) }
        let optimisticFoodName = foodIdForRequest.flatMap { foodId in
            availableFoods.first(where: { $0.id == foodId })?.name
        }
        let optimisticUnitId = unitIdForRequest.flatMap { UUID(uuidString: $0) }
        let optimisticUnitName = unitIdForRequest.flatMap { unitId in
            availableUnits.first(where: { $0.id == unitId })?.name
        }
        let optimisticDisplay = buildDisplayText(note: note, foodName: optimisticFoodName, quantity: quantity, unitName: optimisticUnitName)
        let tempItemId = UUID()

        let optimisticItem = ShoppingListItem(
            id: tempItemId,
            shoppingListId: listId,
            quantity: quantity,
            checked: false,
            position: 0,
            note: note,
            display: optimisticDisplay,
            foodId: optimisticFoodId,
            food: optimisticFoodName.map { RecipeIngredient.IngredientFoodStub(id: foodIdForRequest ?? "", name: $0) },
            unitId: optimisticUnitId,
            unit: optimisticUnitName.map { RecipeIngredient.IngredientUnitStub(id: unitIdForRequest ?? "", name: $0) },
            labelId: nil,
            recipeReferences: nil
        )

        if shoppingListDetail != nil {
            var currentItems = shoppingListDetail!.listItems
            currentItems.insert(optimisticItem, at: 0)
            currentItems.sort { !$0.checked && $1.checked }
            applyListItems(currentItems)
        }

        errorMessage = nil

        if closeSheetAfterSave {
            showingAddItemSheet = false
            addMultipleMode = false
            resetNewItemFields()
        } else {
            newItemNote = ""
        }

        Task {
            do {
                let response = try await apiClient.addShoppingListItem(
                    listId: listId,
                    note: note,
                    quantity: quantity,
                    foodId: foodIdForRequest,
                    unitId: unitIdForRequest
                )

                await MainActor.run {
                    guard shoppingListDetail != nil else { return }
                    var currentItems = shoppingListDetail!.listItems

                    if let createdItem = response.createdItems?.first {
                        if let idx = currentItems.firstIndex(where: { $0.id == tempItemId }) {
                            // Merge: prefer server data but preserve optimistic display/food/unit
                            // if the server didn't return them
                            var merged = createdItem
                            let optimistic = currentItems[idx]
                            if merged.display == nil || merged.display?.isEmpty == true {
                                merged.display = optimistic.display
                            }
                            if merged.food == nil, optimistic.food != nil {
                                merged.food = optimistic.food
                            }
                            if merged.unit == nil, optimistic.unit != nil {
                                merged.unit = optimistic.unit
                            }
                            currentItems[idx] = merged
                        } else {
                            currentItems.insert(createdItem, at: 0)
                        }
                    } else {
                        currentItems.removeAll { $0.id == tempItemId }
                    }

                    currentItems.sort { !$0.checked && $1.checked }
                    applyListItems(currentItems)
                }
            } catch {
                await MainActor.run {
                    if shoppingListDetail != nil {
                        var currentItems = shoppingListDetail!.listItems
                        currentItems.removeAll { $0.id == tempItemId }
                        applyListItems(currentItems)
                    }
                    errorMessage = "Failed to add item: \(error.localizedDescription)"
                }
            }
        }
    }
    
    @MainActor
    func updateItemCheckedState(itemId: UUID, isChecked: Bool) {
        guard shoppingListDetail != nil,
              let index = shoppingListDetail!.listItems.firstIndex(where: { $0.id == itemId })
        else { return }

        guard shoppingListDetail!.listItems[index].checked != isChecked else { return }

        var updatedItems = shoppingListDetail!.listItems
        updatedItems[index].checked = isChecked
        updatedItems.sort { !$0.checked && $1.checked }
        applyListItems(updatedItems)

        if let itemToSend = updatedItems.first(where: { $0.id == itemId }) {
            Task { await persistCheckedState(item: itemToSend, isChecked: isChecked) }
        }
    }
    
    @MainActor
    private func persistCheckedState(item: ShoppingListItem, isChecked: Bool) async {
        guard let apiClient else {
            errorMessage = "Cannot update item: API client missing."
            return
        }
        errorMessage = nil
        
        do {
            _ = try await apiClient.updateShoppingListItemCheckedState(
                itemId: item.id,
                shoppingListId: item.shoppingListId,
                note: item.syncNoteValue,
                quantity: item.quantity,
                checked: isChecked,
                foodId: item.foodId,
                unitId: item.unitId,
                labelId: item.labelId,
                position: item.position
            )
        } catch APIError.unauthorized {
            await loadListDetails(apiClient: apiClient)
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
            await loadListDetails(apiClient: apiClient)
        }
    }
    
    @MainActor
    func importMealPlanIngredients(startDate: Date, endDate: Date) async {
        guard let apiClient, let listId = shoppingListDetail?.id else {
            errorMessage = "Cannot import: API Client or List ID missing."
            return
        }
        
        isLoadingImport = true
        errorMessage = nil
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startDateString = dateFormatter.string(from: startOfDay)
        let endDateString = dateFormatter.string(from: endDate)
        
        do {
            let mealPlanResponse = try await apiClient.fetchMealPlanEntries(startDate: startDateString, endDate: endDateString)
            let recipeIds = mealPlanResponse.items.compactMap { $0.recipeId }
            let uniqueRecipeIds = Array(Set(recipeIds))
            
            if !uniqueRecipeIds.isEmpty {
                _ = try await apiClient.addRecipesToShoppingListBulk(listId: listId, recipeIds: uniqueRecipeIds)
                
                await loadListDetails(apiClient: apiClient)
            } else {
                isLoadingImport = false
            }
        } catch APIError.unauthorized {
            isLoadingImport = false
        } catch {
            errorMessage = "Failed to import meal plan ingredients: \(error.localizedDescription)"
            isLoadingImport = false
        }
    }
    
    @MainActor
    func importCurrentWeekIngredients() async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            errorMessage = "Could not determine current week interval."
            return
        }
        let startDate = weekInterval.start
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        await importMealPlanIngredients(startDate: startDate, endDate: endDate)
    }

    @MainActor
    func importNextWeekIngredients() async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date().addingTimeInterval(8 * 86400)) else {
            errorMessage = "Could not determine next week interval."
            return
        }
        let startDate = weekInterval.start
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        await importMealPlanIngredients(startDate: startDate, endDate: endDate)
    }
    
    @MainActor
    func deleteItems(at offsets: IndexSet) async {
        guard let apiClient, let items = shoppingListDetail?.listItems else {
            errorMessage = "Cannot delete items: API client or items missing."
            return
        }
        
        let itemsToDelete = offsets.map { items[$0] }
        let originalIndices = offsets.map { $0 }
        
        var currentItems = shoppingListDetail!.listItems
        for index in offsets.sorted().reversed() {
            currentItems.remove(at: index)
        }
        applyListItems(currentItems)
        
        for (idx, item) in itemsToDelete.enumerated() {
            errorMessage = nil
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                var restoredItems = shoppingListDetail?.listItems ?? []
                let insertPos = min(originalIndices[idx], restoredItems.count)
                restoredItems.insert(item, at: insertPos)
                applyListItems(restoredItems)
                break
            } catch {
                errorMessage = "Failed to delete item '\(item.resolvedDisplayName)': \(error.localizedDescription)"
                var restoredItems = shoppingListDetail?.listItems ?? []
                let insertPos = min(originalIndices[idx], restoredItems.count)
                restoredItems.insert(item, at: insertPos)
                applyListItems(restoredItems)
                break
            }
        }
    }

    @MainActor
    func removeCheckedItems() async {
        guard let apiClient, let currentItems = shoppingListDetail?.listItems else {
            errorMessage = "Cannot remove checked items: API client or items missing."
            return
        }

        let checkedItems = currentItems.filter { $0.checked }
        guard !checkedItems.isEmpty else { return }

        isLoadingBulkUpdate = true
        errorMessage = nil

        var uncheckedItems = shoppingListDetail?.listItems ?? []
        uncheckedItems.removeAll { $0.checked }
        applyListItems(uncheckedItems)

        for item in checkedItems {
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                var restoredItems = shoppingListDetail?.listItems ?? []
                restoredItems.append(item)
                restoredItems.sort { !$0.checked && $1.checked }
                applyListItems(restoredItems)
                isLoadingBulkUpdate = false
                break
            } catch {
                var restoredItems = shoppingListDetail?.listItems ?? []
                restoredItems.append(item)
                restoredItems.sort { !$0.checked && $1.checked }
                applyListItems(restoredItems)
                errorMessage = "Failed to remove checked items: \(error.localizedDescription)"
                isLoadingBulkUpdate = false
                break
            }
        }

        isLoadingBulkUpdate = false
    }
    
    @MainActor
    func prepareAddItemSheet(addMultiple: Bool = false) {
        resetNewItemFields()
        addMultipleMode = addMultiple
        showingAddItemSheet = true
    }

    @MainActor
    func prepareEditItemSheet(item: ShoppingListItem) {
        editingItemId = item.id
        editItemNote = item.note ?? ""
        editItemQuantity = max(1, item.quantity ?? 1)
        editItemQuantityInput = formatQuantityInput(editItemQuantity)
        selectedFoodIdForEditItem = item.foodId?.uuidString.lowercased()
        selectedUnitIdForEditItem = item.unitId?.uuidString.lowercased()
        errorMessage = nil
        showingEditItemSheet = true

        Task {
            await loadUnitsForNewItemIfNeeded()
            await loadFoodsForItemIfNeeded()
        }
    }

    @MainActor
    func loadUnitsForNewItemIfNeeded() async {
        guard availableUnits.isEmpty, !isLoadingUnits else { return }
        guard let apiClient else { return }

        isLoadingUnits = true
        defer { isLoadingUnits = false }

        do {
            let unitPagination = try await apiClient.getUnits(page: 1, perPage: 500)
            availableUnits = unitPagination.items
                .map { RecipeIngredient.IngredientUnitStub(id: $0.id.lowercased(), name: $0.name) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = "Failed to load units: \(error.localizedDescription)"
        }
    }

    @MainActor
    func loadFoodsForItemIfNeeded() async {
        guard availableFoods.isEmpty, !isLoadingFoods else { return }
        guard let apiClient else { return }

        isLoadingFoods = true
        defer { isLoadingFoods = false }

        do {
            let foodPagination = try await apiClient.searchFoods(query: "", page: 1, perPage: 500)
            availableFoods = foodPagination.items
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            errorMessage = "Failed to load foods: \(error.localizedDescription)"
        }
    }

    @MainActor
    func setNewItemQuantityFromStepper(_ value: Int) {
        newItemQuantity = Double(value)
        newItemQuantityInput = formatQuantityInput(newItemQuantity)
    }

    @MainActor
    func setEditItemQuantityFromStepper(_ value: Int) {
        editItemQuantity = Double(value)
        editItemQuantityInput = formatQuantityInput(editItemQuantity)
    }

    @MainActor
    func syncQuantityFromInput() {
        let trimmed = newItemQuantityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized), parsed > 0 {
            newItemQuantity = parsed
        }
    }

    @MainActor
    func syncEditQuantityFromInput() {
        let trimmed = editItemQuantityInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized), parsed > 0 {
            editItemQuantity = parsed
        }
    }

    @MainActor
    func saveEditedItem() async {
        guard let apiClient,
              let listId = shoppingListDetail?.id,
              let itemId = editingItemId,
              let index = shoppingListDetail?.listItems.firstIndex(where: { $0.id == itemId })
        else {
            errorMessage = "Cannot edit item: missing data."
            return
        }

        syncEditQuantityFromInput()

        let trimmedNote = editItemNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty || selectedFoodIdForEditItem != nil else {
            errorMessage = "Item name or food is required."
            return
        }
        guard editItemQuantity > 0 else {
            errorMessage = "Quantity must be greater than 0."
            return
        }

        errorMessage = nil

        let originalItem = shoppingListDetail!.listItems[index]
        var item = originalItem
        item.shoppingListId = listId
        item.note = trimmedNote
        item.quantity = editItemQuantity

        let editFoodName = selectedFoodIdForEditItem.flatMap { foodId in
            availableFoods.first(where: { $0.id == foodId })?.name
        }

        if let foodIdString = selectedFoodIdForEditItem,
           let foodId = UUID(uuidString: foodIdString) {
            item.foodId = foodId
            item.food = editFoodName.map { RecipeIngredient.IngredientFoodStub(id: foodIdString, name: $0) }
        } else {
            item.foodId = nil
            item.food = nil
        }

        let editUnitName = selectedUnitIdForEditItem.flatMap { unitId in
            availableUnits.first(where: { $0.id == unitId })?.name
        }

        if let unitIdString = selectedUnitIdForEditItem,
           let unitId = UUID(uuidString: unitIdString) {
            item.unitId = unitId
            item.unit = editUnitName.map { RecipeIngredient.IngredientUnitStub(id: unitIdString, name: $0) }
        } else {
            item.unitId = nil
            item.unit = nil
        }

        item.display = buildDisplayText(note: trimmedNote, foodName: editFoodName, quantity: editItemQuantity, unitName: editUnitName)

        var currentItems = shoppingListDetail!.listItems
        currentItems[index] = item
        currentItems.sort { !$0.checked && $1.checked }
        applyListItems(currentItems)

        showingEditItemSheet = false
        editingItemId = nil

        Task {
            do {
                let response = try await apiClient.updateShoppingListItem(item: item)

                await MainActor.run {
                    guard shoppingListDetail != nil,
                          let idx = shoppingListDetail!.listItems.firstIndex(where: { $0.id == item.id })
                    else { return }

                    var items = shoppingListDetail!.listItems
                    if let updated = response.updatedItems?.first(where: { $0.id == item.id }) {
                        items[idx] = updated
                    }
                    items.sort { !$0.checked && $1.checked }
                    applyListItems(items)
                }
            } catch {
                await MainActor.run {
                    if shoppingListDetail != nil,
                       let idx = shoppingListDetail!.listItems.firstIndex(where: { $0.id == originalItem.id }) {
                        var items = shoppingListDetail!.listItems
                        items[idx] = originalItem
                        items.sort { !$0.checked && $1.checked }
                        applyListItems(items)
                    }
                    errorMessage = "Failed to update item: \(error.localizedDescription)"
                }
            }
        }
    }

    private func formatQuantityInput(_ quantity: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
    }

    private func buildDisplayText(note: String, foodName: String?, quantity: Double, unitName: String?) -> String {
        let quantityText = formatQuantityInput(quantity)
        let trimmedUnit = unitName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFood = foodName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Build the descriptor: prefer food name as primary, append note in parentheses if both exist
        let descriptor: String = {
            if !trimmedFood.isEmpty && !trimmedNote.isEmpty {
                return "\(trimmedFood) (\(trimmedNote))"
            } else if !trimmedFood.isEmpty {
                return trimmedFood
            } else if !trimmedNote.isEmpty {
                return trimmedNote
            }
            return ""
        }()

        var parts: [String] = [quantityText]
        if !trimmedUnit.isEmpty { parts.append(trimmedUnit) }
        if !descriptor.isEmpty { parts.append(descriptor) }
        return parts.joined(separator: " ")
    }

    @MainActor
    private func applyListItems(_ items: [ShoppingListItem]) {
        guard var detail = shoppingListDetail else { return }
        detail.listItems = items
        shoppingListDetail = detail
    }
    
    @MainActor
    func resetNewItemFields() {
        newItemNote = ""
        newItemQuantity = 1.0
        newItemQuantityInput = "1"
        selectedFoodIdForNewItem = nil
        selectedUnitIdForNewItem = nil
        errorMessage = nil
    }

    var displayCreatedAt: String? {
        formatDateString(shoppingListDetail?.createdAt)
    }
    var displayUpdatedAt: String? {
        formatDateString(shoppingListDetail?.updatedAt)
    }
    
    private func formatDateString(_ dateString: String?) -> String? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date.formatted(date: .numeric, time: .shortened)
        }
        return dateString
    }
}
