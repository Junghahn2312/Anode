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
    let rank: Int?
    let onFocus: ((MediaItem) -> Void)?
    
    @Environment(\.isFocused) private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    @State private var loadedLogoPath: String? = nil
    
    public init(
        item: MediaItem,
        normalWidth: CGFloat = 190,
        showCinemaBadge: Bool = false,
        rank: Int? = nil,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.item = item
        self.normalWidth = normalWidth
        self.showCinemaBadge = showCinemaBadge
        self.rank = rank
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
            
            // Overlays
            if isFocused {
                // Soft bottom gradient for logo legibility
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.25),
                        .init(color: Color.black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // ONLY the media's logo artwork (no text, no rating, no genre, no cinema badge)
                VStack {
                    Spacer()
                    HStack {
                        if let logoPath = loadedLogoPath ?? item.logoPath,
                           let logoURL = URL(string: logoPath.hasPrefix("http") ? logoPath : "https://image.tmdb.org/t/p/w500\(logoPath)") {
                            CachedAsyncImage(url: logoURL, contentMode: .fit)
                                .frame(maxWidth: expandedWidth * 0.58, maxHeight: cardHeight * 0.42, alignment: .bottomLeading)
                                .shadow(color: Color.black.opacity(0.90), radius: 6, x: 0, y: 3)
                        } else {
                            Text(item.title.uppercased())
                                .font(.system(size: 20, weight: .black, design: .serif))
                                .tracking(1.8)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .shadow(color: Color.black.opacity(0.95), radius: 6, x: 0, y: 3)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .transition(.opacity)
            } else {
                // Unfocused state: subtle rank numeral if top 10, or rating badge
                if let rank = rank {
                    VStack {
                        HStack {
                            Text("\(rank)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.90), radius: 6, x: 0, y: 2)
                                .padding(.top, 10)
                                .padding(.leading, 12)
                            Spacer()
                        }
                        Spacer()
                    }
                } else if !item.formattedRating.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            RatingBadge(rating: item.formattedRating)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            
            // Crisp White Outline on Focus
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2.5)
        }
        .frame(width: isFocused ? expandedWidth : normalWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .zIndex(isFocused ? 20 : 1)
        .shadow(
            color: Color.black.opacity(isFocused ? 0.8 : 0.25),
            radius: isFocused ? 24 : 6,
            x: 0,
            y: isFocused ? 10 : 2
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: isFocused)
        .task(id: item.id) {
            if item.logoPath != nil {
                loadedLogoPath = item.logoPath
            } else {
                loadedLogoPath = await DiscoveryEngine.shared.fetchLogo(for: item)
            }
        }
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
                            TVExpandingMediaCardView(
                                item: item,
                                normalWidth: 185,
                                rank: index + 1
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
