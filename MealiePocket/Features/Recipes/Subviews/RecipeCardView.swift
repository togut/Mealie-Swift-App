import SwiftUI

extension URL {
    static func makeImageURL(baseURL: URL?, recipeID: UUID, imageName: String) -> URL? {
        guard let baseURL else { return nil }
        return baseURL.appendingPathComponent("api/media/recipes/\(recipeID.rfc4122String)/images/\(imageName)")
    }
}

struct RecipeCardView: View {
    let recipe: RecipeSummary
    let baseURL: URL?
    
    private let cardHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImageView(
                url: .makeImageURL(
                    baseURL: baseURL,
                    recipeID: recipe.id,
                    imageName: "min-original.webp"
                )
            )
            .frame(height: 150)
            .cornerRadius(10)
            .padding(.bottom, 8)

            Text(recipe.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 6)
            
            HStack() {
                if let totalTime = recipe.totalTime, !totalTime.isEmpty {
                    Label(totalTime, systemImage: "clock")
                }

                if let rating = recipe.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer(minLength: 0)
        }
        .frame(height: cardHeight)
    }
}

