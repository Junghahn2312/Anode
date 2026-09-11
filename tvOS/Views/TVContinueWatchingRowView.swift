import SwiftUI

public struct TVContinueWatchingRowView: View {
    let items: [ContinueWatchingItem]
    let onHover: ((MediaItem) -> Void)?
    let onSelect: (MediaItem) -> Void
    
    public init(
        items: [ContinueWatchingItem],
        onHover: ((MediaItem) -> Void)? = nil,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.items = items
        self.onHover = onHover
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Background Trakt Sync Button (No Dropdown)
            HStack {
                TVContinueWatchingSyncButton()
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 60)
            .focusSection()
            
            // Horizontal Carousel of 16:9 Landscape Continue Watching Cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(items) { cwItem in
                        Button {
                            onSelect(cwItem.item)
                        } label: {
                            TVContinueWatchingCardView(
                                continueItem: cwItem,
                                width: 340
                            ) { focusedMedia in
                                onHover?(focusedMedia)
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
        .focusSection()
    }
}

// MARK: - Dedicated Focusable Continue Watching Trakt Sync Button

public struct TVContinueWatchingSyncButton: View {
    @ObservedObject private var trakt = TraktStore.shared
    @Environment(\.isFocused) private var isFocused: Bool
    
    public init() {}
    
    public var body: some View {
        Button {
            Task {
                await trakt.refresh()
            }
        } label: {
            HStack(spacing: 8) {
                Text("Continue Watching")
                    .font(.system(size: 16, weight: .bold))
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(trakt.isSyncing ? .degrees(360) : .zero)
                    .animation(trakt.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: trakt.isSyncing)
                
                if trakt.isSyncing {
                    Text("Syncing...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isFocused ? Color.black.opacity(0.8) : Color.white.opacity(0.85))
                }
            }
            .foregroundColor(isFocused ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isFocused ? Color.white : Color.white.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(isFocused ? 1.0 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.tvCard)
    }
}

// MARK: - Dedicated Continue Watching Landscape Card with Progress Bar

public struct TVContinueWatchingCardView: View {
    let continueItem: ContinueWatchingItem
    let width: CGFloat
    let onFocus: ((MediaItem) -> Void)?
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    public init(
        continueItem: ContinueWatchingItem,
        width: CGFloat = 340,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.continueItem = continueItem
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 9.0 / 16.0
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                // Backdrop Artwork
                let imageURL = continueItem.item.backdropURL(size: "w780") ?? continueItem.item.posterURL(size: "original")
                CachedAsyncImage(url: imageURL)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                // Crisp White Outline on Focus
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2.5)
                
                // Gradient Scrim for Readability
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                // Play Icon Overlay when Focused
                if isFocused {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 2)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Bottom Metadata & Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    Text(continueItem.item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(continueItem.formattedProgress)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        
                        Spacer()
                    }
                    
                    // Playback Progress Bar (Trakt progress indicator)
                    GeometryReader { pGeo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.30))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(Color.red)
                                .frame(width: max(8, pGeo.size.width * CGFloat(continueItem.progress)), height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: Color.black.opacity(isFocused ? 0.75 : 0.25),
                radius: isFocused ? 24 : 6,
                x: 0,
                y: isFocused ? 10 : 2
            )
            .animation(.spring(response: 0.40, dampingFraction: 0.86), value: isFocused)
        }
        .frame(width: width)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(continueItem.item)
            }
        }
    }
}
