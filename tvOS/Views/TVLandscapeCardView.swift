import SwiftUI

public struct TVLandscapeCardView: View {
    let item: MediaItem
    let width: CGFloat
    let subtitle: String?
    let onFocus: ((MediaItem) -> Void)?
    
    @Environment(\.isFocused) private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(
        item: MediaItem,
        width: CGFloat = 360,
        subtitle: String? = nil,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.item = item
        self.width = width
        self.subtitle = subtitle
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 9.0 / 16.0
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: item.backdropURL(size: "w780"))
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Crisp white outline over card on focus
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                
                // Subtle bottom gradient for readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Overlay text inside card
                VStack(alignment: .leading, spacing: 4) {
                    if let subtitle {
                        Text(subtitle.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.3))
                    } else if item.inCinemas {
                        Text("IN CINEMAS")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.8)
                            .foregroundColor(.red)
                    }
                    
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(14)
                
                // Top right badges
                VStack {
                    HStack {
                        Spacer()
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                        }
                    }
                    Spacer()
                }
                .padding(10)
            }
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .shadow(
                color: Color.black.opacity(isFocused ? 0.75 : 0.25),
                radius: isFocused ? 24 : 6,
                x: 0,
                y: isFocused ? 10 : 2
            )
            .animation(.spring(response: 0.24, dampingFraction: 0.85), value: isFocused)
        }
        .frame(width: width)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
    }
}
