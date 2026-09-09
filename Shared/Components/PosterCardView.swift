import SwiftUI

public struct PosterCardView: View {
    let item: MediaItem
    let width: CGFloat
    
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(item: MediaItem, width: CGFloat = 140) {
        self.item = item
        self.width = width
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                
                // Rating badge top right
                if !item.formattedRating.isEmpty {
                    RatingBadge(rating: item.formattedRating)
                        .padding(6)
                }
                
                // Watchlist indicator top left
                if watchlist.contains(id: item.id) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                        Spacer()
                    }
                    .padding(6)
                }
            }
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !item.yearString.isEmpty {
                        Text(item.yearString)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    if let genre = item.genreNames.first {
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        Text(genre)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: width, alignment: .leading)
        }
    }
}
