import SwiftUI

public struct BackdropCardView: View {
    let item: MediaItem
    let width: CGFloat
    
    public init(item: MediaItem, width: CGFloat = 280) {
        self.item = item
        self.width = width
    }
    
    private var height: CGFloat {
        width * (9.0 / 16.0)
    }
    
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: item.backdropURL(size: "w780"))
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                if let tagline = item.tagline, !tagline.isEmpty {
                    Text(tagline.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !item.formattedRating.isEmpty {
                        RatingBadge(rating: item.formattedRating)
                    }
                }
            }
            .padding(12)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}
