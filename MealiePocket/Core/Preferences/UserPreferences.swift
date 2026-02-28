import Foundation

class UserPreferences {
    private static let pinnedShoppingListsKey = "com.nohitdev.MealiePocket.pinnedShoppingLists"
    
    static func addPinnedShoppingList(_ listId: UUID) {
        var pinnedIds = getPinnedShoppingListIds()
        pinnedIds.removeAll { $0 == listId }
        pinnedIds.insert(listId, at: 0)
        savePinnedShoppingListIds(pinnedIds)
    }
    
    static func removePinnedShoppingList(_ listId: UUID) {
        var pinnedIds = getPinnedShoppingListIds()
        pinnedIds.removeAll { $0 == listId }
        savePinnedShoppingListIds(pinnedIds)
    }
    
    static func getPinnedShoppingListIds() -> [UUID] {
        if let data = UserDefaults.standard.data(forKey: pinnedShoppingListsKey),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            return ids
        }
        return []
    }
    
    static func isPinnedShoppingList(_ listId: UUID) -> Bool {
        getPinnedShoppingListIds().contains(listId)
    }
    
    private static func savePinnedShoppingListIds(_ ids: [UUID]) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: pinnedShoppingListsKey)
        }
    }
}
