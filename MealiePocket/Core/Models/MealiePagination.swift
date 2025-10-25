import Foundation

struct IngredientUnitPagination: Codable {
    var items: [RecipeIngredient.IngredientUnitStub]
    var page: Int
    var perPage: Int
    var total: Int
    var totalPages: Int
}

struct IngredientFoodPagination: Codable {
    var items: [RecipeIngredient.IngredientFoodStub]
    var page: Int
    var perPage: Int
    var total: Int
    var totalPages: Int
}
