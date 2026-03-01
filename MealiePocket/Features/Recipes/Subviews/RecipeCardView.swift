import SwiftUI

struct RecipeCardView: View {
    @Binding var recipe: RecipeSummary
    let baseURL: URL?
    var showFavoriteButton: Bool = true
    var onFavoriteToggle: (() -> Void)?

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
                .frame(width: 170, height: 170)
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
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            
            HStack() {
                if let totalTime = recipe.totalTime, !totalTime.isEmpty {
                    Label(totalTime, systemImage: "clock")
                        .lineLimit(1)
                }

                if let userRating = recipe.userRating, userRating > 0 {
                    Label(String(format: "%.1f", userRating), systemImage: "star.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer(minLength: 0)
        }
        .frame(width: 170)
        .frame(minHeight: 250)
    }
    
    @ViewBuilder
    private var favoriteButton: some View {
        if let onFavoriteToggle {
            Button {
                hapticImpact(style: .light)
                onFavoriteToggle()
            } label: {
                Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(recipe.isFavorite ? .red : .white)
                    .padding(8)
                    .background(Circle().fill(.black.opacity(0.5)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding([.top, .trailing], 6)
        }
    }
}
