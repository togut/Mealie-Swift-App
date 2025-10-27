import Foundation

extension URL {
    static func makeImageURL(baseURL: URL?, recipeID: UUID, imageName: String, cacheBuster: String? = nil) -> URL? {
        guard let baseURL else { return nil }
        
        let baseImageURL = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("media")
            .appendingPathComponent("recipes")
            .appendingPathComponent(recipeID.rfc4122String)
            .appendingPathComponent("images")
            .appendingPathComponent(imageName)

        if let buster = cacheBuster, var components = URLComponents(url: baseImageURL, resolvingAgainstBaseURL: false) {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "v", value: buster))
            components.queryItems = queryItems
            return components.url
        }

        return baseImageURL
    }
}
