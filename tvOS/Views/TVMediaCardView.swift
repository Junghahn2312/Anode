import SwiftUI

public struct TVMediaCardView: View {
    let item: MediaItem
    let width: CGFloat
    let onFocus: ((MediaItem) -> Void)?
    
    @FocusState private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(item: MediaItem, width: CGFloat = 220, onFocus: ((MediaItem) -> Void)? = nil) {
        self.item = item
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isFocused ? Color.white : Color.white.opacity(0.1), lineWidth: isFocused ? 3 : 0.5)
                    )
                
                if !item.formattedRating.isEmpty {
                    RatingBadge(rating: item.formattedRating)
                        .padding(10)
                }
                
                if watchlist.contains(id: item.id) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.8)))
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(color: isFocused ? Color.white.opacity(0.25) : Color.black.opacity(0.5), radius: isFocused ? 20 : 8, x: 0, y: isFocused ? 10 : 4)
            .animation(.easeInOut(duration: 0.22), value: isFocused)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: isFocused ? .bold : .medium))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.85))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !item.yearString.isEmpty {
                        Text(item.yearString)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if let genre = item.genreNames.first {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        Text(genre)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
    }
}
