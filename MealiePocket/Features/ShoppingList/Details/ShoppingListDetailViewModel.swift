import Foundation
import SwiftUI

@Observable
class ShoppingListDetailViewModel {
    var shoppingListDetail: ShoppingListDetail?
    var recipeNameMap: [UUID: String] = [:]
    var isLoading = false
    var isLoadingBulkUpdate = false
    var isLoadingImport = false
    var errorMessage: String?
    
    var showingAddItemSheet = false
    var newItemNote: String = ""
    var newItemQuantity: Double = 1.0
    
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
            
        } catch {
            errorMessage = "Failed to load list details: \(error.localizedDescription)"
        }
        
        isLoading = false
        isLoadingImport = false
    }
    
    @MainActor
    func addItem() async {
        guard let apiClient, let listId = shoppingListDetail?.id else {
            errorMessage = "Cannot add item: API client or List ID missing."
            return
        }
        guard !newItemNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Item name cannot be empty."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiClient.addShoppingListItem(listId: listId, note: newItemNote, quantity: newItemQuantity)
            if let newItem = response.createdItems?.first {
                if shoppingListDetail != nil {
                    var currentItems = shoppingListDetail!.listItems
                    currentItems.insert(newItem, at: 0)
                    currentItems.sort { !$0.checked && $1.checked }
                    shoppingListDetail!.listItems = currentItems
                    
                }
            }
            showingAddItemSheet = false
            resetNewItemFields()
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "Failed to add item: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    func updateItemCheckedState(itemId: UUID, isChecked: Bool) {
        guard shoppingListDetail != nil,
              let index = shoppingListDetail!.listItems.firstIndex(where: { $0.id == itemId }) else {
            print("Could not find item to update state.")
            return
        }
        
        if shoppingListDetail!.listItems[index].checked != isChecked {
            var updatedItems = shoppingListDetail!.listItems
            updatedItems[index].checked = isChecked
            updatedItems.sort { !$0.checked && $1.checked }
            shoppingListDetail!.listItems = updatedItems
            
            let itemToSend = updatedItems.first { $0.id == itemId } ?? updatedItems[index]
            
            
            Task {
                await persistCheckedState(item: itemToSend, isChecked: isChecked)
            }
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
        
        
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startOfDay)
        let endDateString = dateFormatter.string(from: endOfDay)
        
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
        print(weekInterval)
        let startDate = weekInterval.start
        
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        
        await importMealPlanIngredients(startDate: startDate, endDate: endDate)
    }

    @MainActor
    func importNextWeekIngredients() async {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: (Date() + (3600 * 24 * 8))) else {
            errorMessage = "Could not determine current week interval."
            return
        }
        print(weekInterval)
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
        
        shoppingListDetail?.listItems.remove(atOffsets: offsets)
        
        for (idx, item) in itemsToDelete.enumerated() {
            errorMessage = nil
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                if shoppingListDetail != nil {
                    let originalIndex = originalIndices[idx]
                    let insertPos = min(originalIndex, shoppingListDetail!.listItems.count)
                    shoppingListDetail!.listItems.insert(item, at: insertPos)
                }
                break
            } catch {
                errorMessage = "Failed to delete item '\(item.resolvedDisplayName)': \(error.localizedDescription)"
                if shoppingListDetail != nil {
                    let originalIndex = originalIndices[idx]
                    let insertPos = min(originalIndex, shoppingListDetail!.listItems.count)
                    shoppingListDetail!.listItems.insert(item, at: insertPos)
                }
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

        shoppingListDetail?.listItems.removeAll { $0.checked }

        for item in checkedItems {
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                var restoredItems = shoppingListDetail?.listItems ?? []
                restoredItems.append(item)
                restoredItems.sort { !$0.checked && $1.checked }
                shoppingListDetail?.listItems = restoredItems
                isLoadingBulkUpdate = false
                break
            } catch {
                var restoredItems = shoppingListDetail?.listItems ?? []
                restoredItems.append(item)
                restoredItems.sort { !$0.checked && $1.checked }
                shoppingListDetail?.listItems = restoredItems
                errorMessage = "Failed to remove checked items: \(error.localizedDescription)"
                isLoadingBulkUpdate = false
                break
            }
        }

        isLoadingBulkUpdate = false
    }
    
    @MainActor
    func prepareAddItemSheet() {
        resetNewItemFields()
        showingAddItemSheet = true
    }
    
    @MainActor
    func resetNewItemFields() {
        newItemNote = ""
        newItemQuantity = 1.0
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
