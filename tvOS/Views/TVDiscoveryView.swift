import SwiftUI

public struct TVDiscoveryView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedFilter: DiscoveryFilter = .all
    @State private var selectedProvider: StreamingProvider = .netflix
    @State private var providerItems: [MediaItem] = []
    @State private var selectedItem: MediaItem?
    @State private var focusedItem: MediaItem?
    @State private var isLoadingProvider: Bool = false
    
    private let tmdb = TMDBService.shared
    
    public enum DiscoveryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
        case streaming = "Streaming"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    private var defaultHeroForFilter: MediaItem? {
        switch selectedFilter {
        case .all:
            return engine.heroSpotlights.first ?? engine.trendingItems.first
        case .movies:
            return engine.popularMovies.first ?? engine.cinemaNow.first
        case .tvShows:
            return engine.popularTV.first ?? engine.trendingItems.first(where: { $0.mediaType == .tvShow })
        case .streaming:
            return (providerItems.isEmpty ? engine.streamingItems : providerItems).first
        }
    }
    
    private var currentHero: MediaItem? {
        if let focusedItem {
            return focusedItem
        }
        return defaultHeroForFilter
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack(alignment: .topLeading) {
                // Ambient Pure Black Base
                Color.black.ignoresSafeArea()
                
                // Full-Bleed Atmospheric Backdrop & Fluid Color Bleed
                if let hero = currentHero {
                    ZStack(alignment: .topLeading) {
                        // Ambient blurred color bleed extending smoothly underneath the rows
                        CachedAsyncImage(url: hero.backdropURL(size: "w780"), contentMode: .fill)
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                            .blur(radius: 80)
                            .opacity(0.38)
                            .clipped()
                        
                        // Crisp Full-Bleed 4K Backdrop Image
                        CachedAsyncImage(url: hero.backdropURL(size: "original"), contentMode: .fill)
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height, alignment: .top)
                            .clipped()
                            .id(hero.id)
                            .transition(.opacity)
                        
                        // Left-to-right gradient for crisp text legibility
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.96), location: 0.0),
                                .init(color: Color.black.opacity(0.85), location: 0.38),
                                .init(color: Color.black.opacity(0.38), location: 0.65),
                                .init(color: Color.clear, location: 0.90)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        
                        // Top-to-bottom fluid fade blending seamlessly into rows underneath
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: Color.clear, location: 0.30),
                                .init(color: Color.black.opacity(0.20), location: 0.44),
                                .init(color: Color.black.opacity(0.65), location: 0.58),
                                .init(color: Color.black.opacity(0.92), location: 0.76),
                                .init(color: Color.black, location: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: hero.id)
                }
                
                // Foreground Layout:
                // Top stationary hero & filters section (~48% height) + Scrollable rows (~52% height)
                VStack(alignment: .leading, spacing: 0) {
                    topShowcaseSection(screenGeo: screenGeo)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.48, alignment: .bottomLeading)
                    
                    // Scrollable Category Rows
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 36) {
                            switch selectedFilter {
                            case .all:
                                allDiscoverySections
                            case .movies:
                                moviesDiscoverySections
                            case .tvShows:
                                tvShowsDiscoverySections
                            case .streaming:
                                streamingDiscoverySections
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 90)
                    }
                    .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.52)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
        .task(id: selectedProvider.id) {
            if selectedFilter == .streaming {
                await loadProviderContent(selectedProvider)
            }
        }
    }
    
    // MARK: - Top Showcase Section
    
    private func topShowcaseSection(screenGeo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Tag & Filter Pills
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("DISCOVERY")
                            .font(.system(size: 12, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                            )
                    )
                    
                    Text("GLOBAL ENTERTAINMENT")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.55))
                }
                
                // Filter Selector with Frosted Glass
                HStack(spacing: 12) {
                    ForEach(DiscoveryFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedFilter = filter
                                focusedItem = nil
                            }
                        } label: {
                            DiscoveryFilterPillLabel(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            )
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                
                // Streaming Provider Row if Streaming filter is active
                if selectedFilter == .streaming {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(StreamingProvider.allCases, id: \.id) { provider in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedProvider = provider
                                        focusedItem = nil
                                    }
                                    Task { await loadProviderContent(provider) }
                                } label: {
                                    StreamingProviderPillLabel(
                                        provider: provider,
                                        isSelected: selectedProvider == provider
                                    )
                                }
                                .buttonStyle(.tvCard)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Hero Metadata Overlay
            if let hero = currentHero {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(hero.mediaType == .movie ? "FEATURED FILM" : "FEATURED SERIES")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.85))
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                    )
                            )
                        
                        if !hero.formattedRating.isEmpty {
                            RatingBadge(rating: hero.formattedRating)
                        }
                        
                        if !hero.yearString.isEmpty {
                            Text(hero.yearString)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let genre = hero.genreNames.first {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text(genre)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Text(hero.title)
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
                    
                    if !hero.overview.isEmpty {
                        Text(hero.overview)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .lineSpacing(2)
                            .frame(maxWidth: 720, alignment: .leading)
                    }
                    
                    HStack(spacing: 14) {
                        Button {
                            selectedItem = hero
                        } label: {
                            DiscoveryHeroPrimaryButtonLabel()
                        }
                        .buttonStyle(.tvCard)
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            DiscoveryHeroBookmarkButtonLabel(isBookmarked: watchlist.contains(id: hero.id))
                        }
                        .buttonStyle(.tvCard)
                    }
                    .padding(.top, 4)
                }
                .animation(.easeInOut(duration: 0.28), value: hero.id)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 38)
    }
    
    // MARK: - All Sections
    
    @ViewBuilder
    private var allDiscoverySections: some View {
        if !engine.trendingItems.isEmpty {
            discoveryRow(title: "Trending Worldwide", items: engine.trendingItems)
        }
        if !engine.popularMovies.isEmpty {
            discoveryRow(title: "Popular Movies", items: engine.popularMovies)
        }
        if !engine.popularTV.isEmpty {
            discoveryRow(title: "Popular TV Series", items: engine.popularTV)
        }
        if !engine.topRated.isEmpty {
            discoveryRow(title: "Critically Acclaimed", items: engine.topRated)
        }
    }
    
    // MARK: - Movies Sections
    
    @ViewBuilder
    private var moviesDiscoverySections: some View {
        if !engine.popularMovies.isEmpty {
            discoveryRow(title: "Trending Movies", items: engine.popularMovies)
        }
        let topMovies = engine.topRated.filter { $0.mediaType == .movie }
        if !topMovies.isEmpty {
            discoveryRow(title: "Highest Rated Movies", items: topMovies)
        }
        if !engine.cinemaNow.isEmpty {
            discoveryRow(title: "Now in Theatres", items: engine.cinemaNow, showCinemaBadge: true)
        }
        if !engine.newReleases.isEmpty {
            let newMovies = engine.newReleases.filter { $0.mediaType == .movie }
            if !newMovies.isEmpty {
                discoveryRow(title: "New Releases", items: newMovies)
            }
        }
    }
    
    // MARK: - TV Shows Sections
    
    @ViewBuilder
    private var tvShowsDiscoverySections: some View {
        if !engine.popularTV.isEmpty {
            discoveryRow(title: "Popular TV Series", items: engine.popularTV)
        }
        let topTV = engine.topRated.filter { $0.mediaType == .tvShow }
        if !topTV.isEmpty {
            discoveryRow(title: "Critically Acclaimed Series", items: topTV)
        }
        if !engine.netflixTrending.isEmpty {
            discoveryRow(title: "Trending on Netflix", items: engine.netflixTrending.filter { $0.mediaType == .tvShow })
        }
        if !engine.disneyTrending.isEmpty {
            discoveryRow(title: "Trending on Disney+", items: engine.disneyTrending.filter { $0.mediaType == .tvShow })
        }
        if !engine.appleTVTrending.isEmpty {
            discoveryRow(title: "Trending on Apple TV+", items: engine.appleTVTrending.filter { $0.mediaType == .tvShow })
        }
    }
    
    // MARK: - Streaming Sections
    
    @ViewBuilder
    private var streamingDiscoverySections: some View {
        let displayItems = providerItems.isEmpty ? engine.streamingItems : providerItems
        discoveryRow(title: "Trending on \(selectedProvider.name)", items: displayItems)
        
        let topRated = displayItems.filter { $0.rating >= 7.8 }
        if !topRated.isEmpty {
            discoveryRow(title: "Highest Rated on \(selectedProvider.name)", items: topRated)
        }
    }
    
    private func loadProviderContent(_ provider: StreamingProvider) async {
        isLoadingProvider = true
        providerItems = await tmdb.fetchStreaming(provider: provider)
        isLoadingProvider = false
    }
    
    // MARK: - Discovery Row
    
    private func discoveryRow(title: String, items: [MediaItem], showCinemaBadge: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            TVMediaCardView(
                                item: item,
                                width: 210,
                                showCinemaBadge: showCinemaBadge
                            ) { focused in
                                handleCardFocus(focused)
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
        }
    }
    
    private func handleCardFocus(_ item: MediaItem) {
        withAnimation(.easeInOut(duration: 0.28)) {
            self.focusedItem = item
        }
    }
}

// MARK: - Dedicated Focusable Buttons & Labels

private struct DiscoveryFilterPillLabel: View {
    let title: String
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: isSelected || isFocused ? .bold : .medium))
            .foregroundColor(isFocused ? .black : (isSelected ? .white : .white.opacity(0.75)))
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.30) : Color.clear))
                    .background(
                        Group {
                            if !isFocused && !isSelected {
                                Capsule().fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .overlay(
                        Capsule()
                            .stroke(isFocused ? Color.clear : Color.white.opacity(isSelected ? 0.4 : 0.16), lineWidth: 1)
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}

private struct StreamingProviderPillLabel: View {
    let provider: StreamingProvider
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(provider.brandColor)
                .frame(width: 8, height: 8)
            
            Text(provider.name)
                .font(.system(size: 14, weight: isSelected || isFocused ? .bold : .medium))
                .foregroundColor(isFocused ? .black : (isSelected ? .white : .white.opacity(0.8)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(isFocused ? Color.white : (isSelected ? provider.brandColor.opacity(0.40) : Color.clear))
                .background(
                    Group {
                        if !isFocused && !isSelected {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(isFocused ? Color.clear : (isSelected ? provider.brandColor.opacity(0.6) : Color.white.opacity(0.16)), lineWidth: 1)
                )
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}

private struct DiscoveryHeroPrimaryButtonLabel: View {
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .black))
            Text("Details")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.22))
                .background(
                    Group {
                        if !isFocused {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                        }
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color(white: 0.9) : Color.white.opacity(0.2), lineWidth: 1.5)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}

private struct DiscoveryHeroBookmarkButtonLabel: View {
    let isBookmarked: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16, weight: .bold))
            Text(isBookmarked ? "In List" : "Add to List")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color(white: 0.35) : Color.white.opacity(0.14))
                .background(
                    Group {
                        if !isFocused {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                        }
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color(white: 0.85) : Color.white.opacity(0.18), lineWidth: 1.5)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}
