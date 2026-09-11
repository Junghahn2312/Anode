import SwiftUI

public struct TopTenCardView: View {
    let rank: Int
    let item: MediaItem
    let width: CGFloat
    let onFocus: ((MediaItem) -> Void)?
    
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused: Bool
    #endif
    
    public init(rank: Int, item: MediaItem, width: CGFloat = 160, onFocus: ((MediaItem) -> Void)? = nil) {
        self.rank = rank
        self.item = item
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: -width * 0.28) {
            // Giant Rank Numeral (Netflix style)
            Text("\(rank)")
                .font(.system(size: height * 0.95, weight: .black, design: .rounded))
                .foregroundColor(Color.black)
                .overlay(
                    Text("\(rank)")
                        .font(.system(size: height * 0.95, weight: .black, design: .rounded))
                        .foregroundColor(Color(white: 0.35))
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: Color.white.opacity(0.15), radius: 2, x: -1, y: -1)
                .shadow(color: Color.black.opacity(0.8), radius: 4, x: 2, y: 2)
                .offset(y: height * 0.08)
                .zIndex(0)
            
            // Poster
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    #if os(tvOS)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isFocused ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2.5)
                    )
                    #endif
                
                if !item.formattedRating.isEmpty {
                    RatingBadge(rating: item.formattedRating)
                        .padding(8)
                }
            }
            .zIndex(1)
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.10 : 1.0)
            .zIndex(isFocused ? 10 : 1)
            .shadow(color: Color.black.opacity(isFocused ? 0.75 : 0.25), radius: isFocused ? 24 : 6, x: 0, y: isFocused ? 10 : 2)
            .animation(.spring(response: 0.24, dampingFraction: 0.85), value: isFocused)
            #else
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
            #endif
        }
        #if os(tvOS)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
        #endif
    }
}
