import Foundation

struct ShoppingListSummary: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    let createdAt: String?
    let updatedAt: String?
    let groupId: UUID
    let userId: UUID
    let householdId: UUID

    static func == (lhs: ShoppingListSummary, rhs: ShoppingListSummary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ShoppingListPagination: Decodable {
    let items: [ShoppingListSummary]
    let totalPages: Int
    let page: Int
    let perPage: Int
    let total: Int
}

struct ShoppingListDetail: Codable, Identifiable {
    let id: UUID
    var name: String?
    let createdAt: String?
    let updatedAt: String?
    let groupId: UUID
    let userId: UUID
    let householdId: UUID
    var listItems: [ShoppingListItem] = []


    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, groupId, userId, householdId, listItems
    }
}


struct ShoppingListItem: Codable, Identifiable, Hashable {
    let id: UUID
    var shoppingListId: UUID
    var quantity: Double?
    var checked: Bool = false
    var position: Int = 0
    var note: String?
    var display: String?
    var foodId: UUID?
    var unitId: UUID?
    var labelId: UUID?


    static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


struct ShoppingListCreate: Codable {
    var name: String?
}

struct ShoppingListUpdate: Codable {
    var name: String?
    var id: UUID
    var groupId: UUID
    var userId: UUID
}

struct ShoppingListItemCreatePayload: Codable {
    var shoppingListId: String
    var note: String? = ""
    var quantity: Double? = 1.0
    
}

struct ShoppingListItemUpdatePayload: Codable {
    var id: String
    var shoppingListId: String
    var note: String?
    var quantity: Double?
    var checked: Bool?
    
}

struct ShoppingListItemsCollectionResponse: Codable {
    var updatedItems: [ShoppingListItem]?
    var createdItems: [ShoppingListItem]?
    var deletedItems: [ShoppingListItem]?
}

extension ShoppingListSummary {
    var displayCreatedAt: String? {
        formatDateString(createdAt)
    }
    var displayUpdatedAt: String? {
        formatDateString(updatedAt)
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
