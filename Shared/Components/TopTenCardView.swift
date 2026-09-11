import SwiftUI

public struct TopTenCardView: View {
    let rank: Int
    let item: MediaItem
    let width: CGFloat
    let onFocus: ((MediaItem) -> Void)?
    
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #endif
    
    public init(rank: Int, item: MediaItem, width: CGFloat = 190, onFocus: ((MediaItem) -> Void)? = nil) {
        self.rank = rank
        self.item = item
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        #if os(tvOS)
        TVExpandingMediaCardView(
            item: item,
            normalWidth: width,
            rank: rank,
            onFocus: onFocus
        )
        #else
        VStack(alignment: .leading, spacing: 8) {
            // Poster Card with subtle rank numeral in top-left corner
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                // Subtle rank number in top left hand corner of the box (Matching Photo 2)
                Text("\(rank)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.90), radius: 6, x: 0, y: 2)
                    .padding(.top, 10)
                    .padding(.leading, 12)
            }
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
            
            // Title & Year below card (Matching Photo 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if !item.yearString.isEmpty {
                    Text(item.yearString)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width)
        #endif
    }
}
