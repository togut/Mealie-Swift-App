import Foundation

extension URL {
    static func makeImageURL(baseURL: URL?, recipeID: UUID, imageName: String) -> URL? {
        guard let baseURL else { return nil }
        
        return baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("media")
            .appendingPathComponent("recipes")
            .appendingPathComponent(recipeID.rfc4122String)
            .appendingPathComponent("images")
            .appendingPathComponent(imageName)
    }
}
