import SwiftUI

// MARK: - Dedicated Inline Row Info Panel (Matching Image 2)

public struct TVRowInfoPanel: View {
    let item: MediaItem
    
    public init(item: MediaItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Metadata Line (Genre • Year • Runtime • Rating Badge • Badges)
            HStack(spacing: 12) {
                if let genre = item.genreNames.first {
                    Text(genre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !item.yearString.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(item.yearString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !item.formattedRuntime.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(item.formattedRuntime)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if let cert = item.certification {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(cert)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
                
                if !item.formattedRating.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    RatingBadge(rating: item.formattedRating)
                }
                
                if item.inCinemas {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("IN CINEMAS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.red)
                    }
                }
                
                if !item.formattedTheatricalReleaseDate.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text("In Cinemas: \(item.formattedTheatricalReleaseDate)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            
            // Synopsis / Overview text (Image 2)
            if !item.overview.isEmpty {
                Text(item.overview)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .lineSpacing(3)
                    .frame(maxWidth: 900, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Dynamic Expanding Media Card (Matching Image 2)

public struct TVExpandingMediaCardView: View {
    let item: MediaItem
    let normalWidth: CGFloat
    let showCinemaBadge: Bool
    let onFocus: ((MediaItem) -> Void)?
    
    @Environment(\.isFocused) private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(
        item: MediaItem,
        normalWidth: CGFloat = 190,
        showCinemaBadge: Bool = false,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.item = item
        self.normalWidth = normalWidth
        self.showCinemaBadge = showCinemaBadge
        self.onFocus = onFocus
    }
    
    private var cardHeight: CGFloat {
        normalWidth * 1.5
    }
    
    private var expandedWidth: CGFloat {
        cardHeight * 16.0 / 9.0
    }
    
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Unfocused: Portrait Poster | Focused: 16:9 Landscape Backdrop
            if isFocused {
                let backdrop = item.backdropURL(size: "w780") ?? item.posterURL(size: "w500")
                CachedAsyncImage(url: backdrop)
                    .frame(width: expandedWidth, height: cardHeight)
                    .clipped()
            } else {
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: normalWidth, height: cardHeight)
                    .clipped()
            }
            
            // Expanded Card Overlays: Title & Badges on artwork when focused
            if isFocused {
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    
                    Text(item.title)
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    
                    HStack(spacing: 8) {
                        if item.inCinemas || showCinemaBadge {
                            Text("IN CINEMAS")
                                .font(.system(size: 10, weight: .black))
                                .tracking(0.8)
                                .foregroundColor(.red)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        if !item.formattedTheatricalReleaseDate.isEmpty && (item.inCinemas || showCinemaBadge) {
                            Text(item.formattedTheatricalReleaseDate)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                        }
                        
                        if let genre = item.genreNames.first {
                            Text(genre)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
                .padding(14)
                .transition(.opacity)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                                .padding(8)
                        }
                    }
                    Spacer()
                }
            }
            
            // Crisp White Outline on Focus
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2.5)
        }
        .frame(width: isFocused ? expandedWidth : normalWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .zIndex(isFocused ? 10 : 1)
        .shadow(
            color: Color.black.opacity(isFocused ? 0.8 : 0.25),
            radius: isFocused ? 24 : 6,
            x: 0,
            y: isFocused ? 10 : 2
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(item)
            }
        }
    }
}

// MARK: - Standard Content Row with Expanding Cards & Inline Info Strip

public struct TVContentRowView: View {
    let title: String
    let items: [MediaItem]
    let showCinemaBadge: Bool
    let isRowActive: Bool
    let onHover: ((MediaItem) -> Void)?
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        showCinemaBadge: Bool = false,
        isRowActive: Bool = false,
        onHover: ((MediaItem) -> Void)? = nil,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.showCinemaBadge = showCinemaBadge
        self.isRowActive = isRowActive
        self.onHover = onHover
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel with Expanding Cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TVExpandingMediaCardView(
                                item: item,
                                normalWidth: 190,
                                showCinemaBadge: showCinemaBadge
                            ) { focused in
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    self.focusedItem = focused
                                }
                                self.onHover?(focused)
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel - Smooth soft transition with zero abrupt disappearing
            ZStack(alignment: .leading) {
                if let active = focusedItem {
                    TVRowInfoPanel(item: active)
                        .opacity(isRowActive ? 1.0 : 0.0)
                        .frame(height: isRowActive ? nil : 0, alignment: .top)
                        .clipped()
                }
            }
            .padding(.horizontal, 60)
            .animation(.easeInOut(duration: 0.50), value: isRowActive)
        }
        .focusSection()
    }
}

// MARK: - Landscape Content Row with Expanding Cards & Inline Info Strip

public struct TVLandscapeRowView: View {
    let title: String
    let items: [MediaItem]
    let isRowActive: Bool
    let onHover: ((MediaItem) -> Void)?
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        isRowActive: Bool = false,
        onHover: ((MediaItem) -> Void)? = nil,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.isRowActive = isRowActive
        self.onHover = onHover
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 34) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TVLandscapeCardView(
                                item: item,
                                width: 380,
                                subtitle: item.releaseDate
                            ) { focused in
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                    self.focusedItem = focused
                                }
                                self.onHover?(focused)
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel - Smooth soft transition with zero abrupt disappearing
            ZStack(alignment: .leading) {
                if let active = focusedItem {
                    TVRowInfoPanel(item: active)
                        .opacity(isRowActive ? 1.0 : 0.0)
                        .frame(height: isRowActive ? nil : 0, alignment: .top)
                        .clipped()
                }
            }
            .padding(.horizontal, 60)
            .animation(.easeInOut(duration: 0.50), value: isRowActive)
        }
        .focusSection()
    }
}

// MARK: - Top 10 Content Row with Expanding Cards & Inline Info Strip

public struct TVTopTenRowView: View {
    let title: String
    let items: [MediaItem]
    let isRowActive: Bool
    let onHover: ((MediaItem) -> Void)?
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        isRowActive: Bool = false,
        onHover: ((MediaItem) -> Void)? = nil,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.isRowActive = isRowActive
        self.onHover = onHover
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 38) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onSelect(item)
                        } label: {
                            TopTenCardView(
                                rank: index + 1,
                                item: item,
                                width: 175
                            ) { focused in
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                                    self.focusedItem = focused
                                }
                                self.onHover?(focused)
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel - Smooth soft transition with zero abrupt disappearing
            ZStack(alignment: .leading) {
                if let active = focusedItem {
                    TVRowInfoPanel(item: active)
                        .opacity(isRowActive ? 1.0 : 0.0)
                        .frame(height: isRowActive ? nil : 0, alignment: .top)
                        .clipped()
                }
            }
            .padding(.horizontal, 60)
            .animation(.easeInOut(duration: 0.50), value: isRowActive)
        }
        .focusSection()
    }
}
