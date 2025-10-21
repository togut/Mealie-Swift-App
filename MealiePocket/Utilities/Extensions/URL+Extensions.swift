import Foundation

extension URL {
    static func makeImageURL(baseURL: URL, recipeID: UUID, imageName: String) -> URL {
        return baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("media")
            .appendingPathComponent("recipes")
            .appendingPathComponent(recipeID.uuidString)
            .appendingPathComponent("images")
            .appendingPathComponent(imageName)
    }
}
