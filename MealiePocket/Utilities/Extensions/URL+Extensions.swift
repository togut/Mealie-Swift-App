import Foundation

extension URL {
    static func makeImageURL(baseURL: URL?, recipeID: UUID, imageName: String) -> URL? {
        guard let baseURL else { return nil }
        return baseURL.appendingPathComponent("api/media/recipes/\(recipeID.rfc4122String)/images/\(imageName)")
    }
}
