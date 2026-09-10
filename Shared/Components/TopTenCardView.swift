import SwiftUI

public struct TopTenCardView: View {
    let rank: Int
    let item: MediaItem
    let width: CGFloat
    let onFocus: ((MediaItem) -> Void)?
    
    #if os(tvOS)
    @FocusState private var isFocused: Bool
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
                    .colorMultiply(isFocused ? Color(white: 1.06) : Color(white: 0.92))
                    #endif
                
                if !item.formattedRating.isEmpty {
                    RatingBadge(rating: item.formattedRating)
                        .padding(8)
                }
            }
            .zIndex(1)
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.07 : 1.0)
            .shadow(color: Color.black.opacity(isFocused ? 0.75 : 0.35), radius: isFocused ? 26 : 8, x: 0, y: isFocused ? 14 : 4)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)
            #else
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
            #endif
        }
        #if os(tvOS)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
        #endif
    }
}
