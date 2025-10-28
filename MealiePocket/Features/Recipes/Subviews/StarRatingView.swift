import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Double
    var maxRating: Int = 5

    var body: some View {
        HStack {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: imageName(for: index))
                    .foregroundColor(.orange)
                    .onTapGesture {
                        hapticImpact(style: .light)
                        rating = Double(index)
                    }
            }
        }
    }

    private func imageName(for index: Int) -> String {
        if Double(index) <= rating {
            return "star.fill"
        } else if Double(index) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}
