import Foundation
import SwiftUI

@Observable
class ShoppingListDetailViewModel {
    var shoppingListDetail: ShoppingListDetail?
    var isLoading = false
    var isLoadingBulkUpdate = false
    var errorMessage: String?
    
    var showingAddItemSheet = false
    var newItemNote: String = ""
    var newItemQuantity: Double = 1.0
    
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
            listItems: []
        )
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
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fullDetails = try await apiClient.fetchShoppingListDetail(listId: listSummary.id)
            var items = fullDetails.listItems
            items.sort { !$0.checked && $1.checked }
            
            self.shoppingListDetail = ShoppingListDetail(
                id: fullDetails.id,
                name: fullDetails.name,
                createdAt: fullDetails.createdAt,
                updatedAt: fullDetails.updatedAt,
                groupId: fullDetails.groupId,
                userId: fullDetails.userId,
                householdId: fullDetails.householdId,
                listItems: items
            )
            
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "Failed to load list details: \(error.localizedDescription)"
        }
        
        isLoading = false
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
                    shoppingListDetail!.listItems.insert(newItem, at: 0)
                    shoppingListDetail!.listItems.sort { !$0.checked && $1.checked }
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
            shoppingListDetail!.listItems[index].checked = isChecked
            let updatedItem = shoppingListDetail!.listItems[index]
            
            Task {
                await updateItem(updatedItem)
            }
        }
    }
    
    @MainActor
    func updateItem(_ item: ShoppingListItem) async {
        guard let apiClient else {
            errorMessage = "Cannot update item: API client missing."
            return
        }
        errorMessage = nil
        
        do {
            _ = try await apiClient.updateShoppingListItem(item: item)
        } catch APIError.unauthorized {
            
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
            print("Error saving item update, local state might be inconsistent.")
        }
    }    
    
    @MainActor
    func toggleAllItems() async {
        guard let apiClient, shoppingListDetail != nil, !shoppingListDetail!.listItems.isEmpty else {
            return
        }
        
        let targetState = hasUncheckedItems
        
        isLoadingBulkUpdate = true
        errorMessage = nil
        
        var updatedItems = shoppingListDetail!.listItems
        var changed = false
        for i in updatedItems.indices {
            if updatedItems[i].checked != targetState {
                updatedItems[i].checked = targetState
                changed = true
            }
        }
        
        if changed {
            updatedItems.sort { !$0.checked && $1.checked }
            shoppingListDetail!.listItems = updatedItems
            
            do {
                _ = try await apiClient.updateShoppingListItemsBulk(items: updatedItems)
            } catch APIError.unauthorized {
                
            } catch {
                errorMessage = "Failed to update all items: \(error.localizedDescription)"
            }
        } else {
            
        }
        
        isLoadingBulkUpdate = false
    }
    
    @MainActor
    func deleteItems(at offsets: IndexSet) async {
        guard let apiClient, let items = shoppingListDetail?.listItems else {
            errorMessage = "Cannot delete items: API client or items missing."
            return
        }
        
        let itemsToDelete = offsets.map { items[$0] }
        
        shoppingListDetail?.listItems.remove(atOffsets: offsets)
        
        for item in itemsToDelete {
            errorMessage = nil
            do {
                try await apiClient.deleteShoppingListItem(itemId: item.id)
            } catch APIError.unauthorized {
                
                if shoppingListDetail != nil {
                    shoppingListDetail!.listItems.insert(item, at: offsets.first!)
                }
                break
            } catch {
                errorMessage = "Failed to delete item '\(item.display ?? item.note ?? "")': \(error.localizedDescription)"
                if shoppingListDetail != nil {
                    shoppingListDetail!.listItems.insert(item, at: offsets.first!)
                }
                break
            }
        }
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
