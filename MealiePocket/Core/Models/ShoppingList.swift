import Foundation

struct DecodableQuantity: Codable, Hashable {
    let parsedValue: Double

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let doubleValue = try? container.decode(Double.self) {
                self.parsedValue = doubleValue
            } else if let intValue = try? container.decode(Int.self) {
                self.parsedValue = Double(intValue)
            } else if container.decodeNil() {
                self.parsedValue = 0.0
            } else {
                throw DecodingError.typeMismatch(DecodableQuantity.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Double, Int, or object for quantity, but found something else"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let doubleValue = try? container.decode(Double.self, forKey: .parsedValue) {
                self.parsedValue = doubleValue
            } else if let intValue = try? container.decode(Int.self, forKey: .parsedValue) {
                self.parsedValue = Double(intValue)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .parsedValue, in: container, debugDescription: "parsedValue is not a valid Double or Int")
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
         var container = encoder.singleValueContainer()
         try container.encode(parsedValue)
     }
    
    enum CodingKeys: String, CodingKey {
        case source, parsedValue
    }
}

struct ShoppingListSummary: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    let createdAt: String?
    let updatedAt: String?
    let groupId: UUID
    let userId: UUID
    let householdId: UUID

    static func == (lhs: ShoppingListSummary, rhs: ShoppingListSummary) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
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
    var recipeReferences: [ShoppingListTopLevelRecipeRef]?
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
    var food: RecipeIngredient.IngredientFoodStub? = nil
    var unitId: UUID?
    var unit: RecipeIngredient.IngredientUnitStub? = nil
    var labelId: UUID?
    var recipeReferences: [ShoppingListItemNestedRef]?

    static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        lhs.id == rhs.id
            && lhs.checked == rhs.checked
            && lhs.note == rhs.note
            && lhs.display == rhs.display
            && lhs.quantity == rhs.quantity
            && lhs.foodId == rhs.foodId
            && lhs.unitId == rhs.unitId
            && lhs.food == rhs.food
            && lhs.unit == rhs.unit
            && lhs.position == rhs.position
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(checked)
        hasher.combine(note)
        hasher.combine(display)
        hasher.combine(quantity)
        hasher.combine(foodId)
        hasher.combine(unitId)
    }

    var resolvedDisplayName: String {
        let trimmedDisplay = display?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDisplay, !trimmedDisplay.isEmpty {
            return trimmedDisplay
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let foodName = food?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unitName = unit?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantityText: String? = {
            guard let quantity, quantity > 0 else { return nil }
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: quantity))
        }()

        // Combine food name and note: food is primary, note appended if both exist
        let descriptor: String? = {
            if let foodName, !foodName.isEmpty {
                if let trimmedNote, !trimmedNote.isEmpty {
                    return "\(foodName) (\(trimmedNote))"
                }
                return foodName
            }
            if let trimmedNote, !trimmedNote.isEmpty { return trimmedNote }
            return nil
        }()

        var parts: [String] = []
        if let quantityText { parts.append(quantityText) }
        if let unitName, !unitName.isEmpty { parts.append(unitName) }
        if let descriptor { parts.append(descriptor) }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        return "Unknown Item"
    }

    var syncNoteValue: String? {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedNote, !trimmedNote.isEmpty else { return nil }
        return trimmedNote
    }
}


struct ShoppingListItemNestedRef: Codable, Identifiable, Hashable {
    let id: UUID
    let shoppingListItemId: UUID
    let recipeId: UUID
    let recipeQuantity: DecodableQuantity?
}


struct ShoppingListTopLevelRecipeRef: Codable, Identifiable, Hashable {
    let id: UUID
    let shoppingListId: UUID
    let recipeId: UUID
    let recipeQuantity: DecodableQuantity?
    let recipe: RecipeSummary?
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
    var foodId: String? = nil
    var unitId: String? = nil
}

struct ShoppingListItemUpdatePayload: Codable {
    var id: String
    var shoppingListId: String
    var note: String?
    var quantity: Double?
    var checked: Bool?
    var foodId: String?
    var unitId: String?
    var labelId: String?
    var position: Int?

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
