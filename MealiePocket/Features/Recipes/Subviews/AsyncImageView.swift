import SwiftUI

struct AsyncImageView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color(.secondarySystemBackground)
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "photo.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                }
            @unknown default:
                EmptyView()
            }
        }
    }
}
