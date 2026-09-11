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
                
                #if os(tvOS)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2.5)
                #endif
            }
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: Color.black.opacity(isFocused ? 0.75 : 0.25),
                radius: isFocused ? 24 : 6,
                x: 0,
                y: isFocused ? 10 : 2
            )
            .animation(.spring(response: 0.40, dampingFraction: 0.86), value: isFocused)
            #else
            .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
            #endif
            
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
        #if os(tvOS)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
        #endif
    }
}
