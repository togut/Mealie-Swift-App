import SwiftUI

struct FavoriteCardView: View {
    @Binding var recipe: RecipeSummary
    let baseURL: URL?
    var showFavoriteButton: Bool = true
    var onFavoriteToggle: (() -> Void)?
    
    private let cardHeight: CGFloat = 230

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImageView(
                    url: .makeImageURL(
                        baseURL: baseURL,
                        recipeID: recipe.id,
                        imageName: "min-original.webp"
                    )
                )
                .frame(width: 150, height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if showFavoriteButton {
                    favoriteButton
                }
            }
            .padding(.bottom, 8)

            Text(recipe.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 6)
            
            HStack() {
                if let totalTime = recipe.totalTime, !totalTime.isEmpty {
                    Label(totalTime, systemImage: "clock")
                        .lineLimit(1)
                }

                if let rating = recipe.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private var favoriteButton: some View {
        if let onFavoriteToggle {
            Button {
                onFavoriteToggle()
            } label: {
                Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(recipe.isFavorite ? .red : .white)
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(8)
        }
    }
}
