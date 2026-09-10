import SwiftUI

public struct TVMediaCardView: View {
    let item: MediaItem
    let width: CGFloat
    let showCinemaBadge: Bool
    let onFocus: ((MediaItem) -> Void)?
    
    @FocusState private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(
        item: MediaItem,
        width: CGFloat = 220,
        showCinemaBadge: Bool = false,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.item = item
        self.width = width
        self.showCinemaBadge = showCinemaBadge
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .colorMultiply(isFocused ? Color(white: 1.06) : Color(white: 0.92))
                
                // Badges overlay
                VStack(alignment: .trailing, spacing: 6) {
                    if !item.formattedRating.isEmpty {
                        RatingBadge(rating: item.formattedRating)
                    }
                    
                    if (item.inCinemas || showCinemaBadge) {
                        Text("CINEMA")
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.6)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.85))
                            )
                    }
                }
                .padding(10)
                
                if watchlist.contains(id: item.id) {
                    VStack {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(Circle().fill(Color.black.opacity(0.75)))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .scaleEffect(isFocused ? 1.07 : 1.0)
            .shadow(
                color: Color.black.opacity(isFocused ? 0.75 : 0.35),
                radius: isFocused ? 26 : 8,
                x: 0,
                y: isFocused ? 14 : 4
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)
            
            // Metadata below card
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: isFocused ? .bold : .medium))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.8))
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
