import Foundation

struct AppInfo: Codable {
    let version: String
    let demoStatus: Bool
    let allowSignup: Bool
    let allowPasswordLogin: Bool
    let enableOpenai: Bool
}

struct HouseholdStatistics: Codable {
    let totalRecipes: Int
    let totalUsers: Int
    let totalCategories: Int
    let totalTags: Int
    let totalTools: Int
}
