import SwiftUI

public struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }
    
    public var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color(white: 0.12)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .clipped()
                case .failure:
                    ZStack {
                        Color(white: 0.10)
                        Image(systemName: "film")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                    }
                @unknown default:
                    Color(white: 0.10)
                }
            }
        } else {
            ZStack {
                Color(white: 0.10)
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}
