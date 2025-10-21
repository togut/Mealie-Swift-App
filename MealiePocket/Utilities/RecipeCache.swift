import Foundation

struct RecipeCache {
    private static let cacheURL: URL? = {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDirectory.appendingPathComponent("recipe_cache.json")
    }()

    static func save(_ recipes: [RecipeSummary]) {
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(recipes)
            try data.write(to: url, options: .atomic)
        } catch {
        }
    }

    static func load() -> [RecipeSummary]? {
        guard let url = cacheURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let recipes = try JSONDecoder().decode([RecipeSummary].self, from: data)
            return recipes
        } catch {
            return nil
        }
    }
}
