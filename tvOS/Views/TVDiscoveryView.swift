import SwiftUI

public struct TVDiscoveryView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedFilter: DiscoveryFilter = .all
    @State private var selectedProvider: StreamingProvider = .netflix
    @State private var providerItems: [MediaItem] = []
    @State private var selectedItem: MediaItem?
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
    
    private var categoryHero: MediaItem? {
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
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack(alignment: .topLeading) {
                // Continuous Cinematic Dark Canvas (Zero Black Bar Cuts)
                Color(red: 0.04, green: 0.04, blue: 0.05)
                    .ignoresSafeArea()
                
                // Ambient Atmospheric Glow Spanning Full Screen
                if let hero = categoryHero {
                    CachedAsyncImage(url: hero.backdropURL(size: "w780"), contentMode: .fill)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        .blur(radius: 110)
                        .opacity(0.32)
                        .clipped()
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.5), value: hero.id)
                }
                
                // Unified Root Vertical ScrollView (Zero Black Bars)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Full-Screen Category Featured Hero Section
                        if let hero = categoryHero {
                            discoveryHeroSection(hero: hero, screenGeo: screenGeo)
                        } else {
                            Color.clear
                                .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        }
                        
                        // 2. Dynamic Content Rows with Dynamic Expanding Cards (Image 2)
                        VStack(alignment: .leading, spacing: 32) {
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
                        .offset(y: -260)
                        .padding(.bottom, 120)
                    }
                }
                .ignoresSafeArea()
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
    
    // MARK: - Category Hero Showcase Section (~820pt, peeking first row below)
    
    private func discoveryHeroSection(hero: MediaItem, screenGeo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Full-Bleed 4K Backdrop Artwork (Spanning 100% Viewport Height)
            CachedAsyncImage(url: hero.backdropURL(size: "original"), contentMode: .fill)
                .frame(width: screenGeo.size.width, height: screenGeo.size.height, alignment: .top)
                .clipped()
                .overlay(
                    // Soft left vignette for typography readability
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.80), location: 0.0),
                            .init(color: Color.black.opacity(0.35), location: 0.35),
                            .init(color: Color.clear, location: 0.65)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    // Soft top vignette for tab bar readability
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.70), location: 0.0),
                            .init(color: Color.clear, location: 0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Bottom fluid translucent fade allowing artwork to shine through bottom row
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.clear, location: 0.52),
                            .init(color: Color.black.opacity(0.40), location: 0.72),
                            .init(color: Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.85), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .id(hero.id)
                .transition(.opacity)
            
            // Hero Content & Filter Header
            VStack(alignment: .leading, spacing: 14) {
                // Top Header Pill & Category Filter Selector
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("DISCOVERY")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1)
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
                .padding(.top, 140)
                
                // Hero Information
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
                        .font(.system(size: 46, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 3)
                    
                    if !hero.overview.isEmpty {
                        Text(hero.overview)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .lineSpacing(3)
                            .frame(maxWidth: 780, alignment: .leading)
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
                    .focusSection()
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 280)
        }
        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
        .animation(.easeInOut(duration: 0.35), value: hero.id)
    }
    
    // MARK: - All Sections
    
    @ViewBuilder
    private var allDiscoverySections: some View {
        if !engine.trendingItems.isEmpty {
            TVContentRowView(title: "Trending Worldwide", items: engine.trendingItems) { item in
                selectedItem = item
            }
        }
        if !engine.popularMovies.isEmpty {
            TVContentRowView(title: "Popular Movies", items: engine.popularMovies) { item in
                selectedItem = item
            }
        }
        if !engine.popularTV.isEmpty {
            TVContentRowView(title: "Popular TV Series", items: engine.popularTV) { item in
                selectedItem = item
            }
        }
        if !engine.topRated.isEmpty {
            TVContentRowView(title: "Critically Acclaimed", items: engine.topRated) { item in
                selectedItem = item
            }
        }
    }
    
    // MARK: - Movies Sections
    
    @ViewBuilder
    private var moviesDiscoverySections: some View {
        if !engine.popularMovies.isEmpty {
            TVContentRowView(title: "Trending Movies", items: engine.popularMovies) { item in
                selectedItem = item
            }
        }
        let topMovies = engine.topRated.filter { $0.mediaType == .movie }
        if !topMovies.isEmpty {
            TVContentRowView(title: "Highest Rated Movies", items: topMovies) { item in
                selectedItem = item
            }
        }
        if !engine.cinemaNow.isEmpty {
            TVContentRowView(title: "Now in Theatres", items: engine.cinemaNow, showCinemaBadge: true) { item in
                selectedItem = item
            }
        }
        if !engine.newReleases.isEmpty {
            let newMovies = engine.newReleases.filter { $0.mediaType == .movie }
            if !newMovies.isEmpty {
                TVContentRowView(title: "New Releases", items: newMovies) { item in
                    selectedItem = item
                }
            }
        }
    }
    
    // MARK: - TV Shows Sections
    
    @ViewBuilder
    private var tvShowsDiscoverySections: some View {
        if !engine.popularTV.isEmpty {
            TVContentRowView(title: "Popular TV Series", items: engine.popularTV) { item in
                selectedItem = item
            }
        }
        let topTV = engine.topRated.filter { $0.mediaType == .tvShow }
        if !topTV.isEmpty {
            TVContentRowView(title: "Critically Acclaimed Series", items: topTV) { item in
                selectedItem = item
            }
        }
        if !engine.netflixTrending.isEmpty {
            TVContentRowView(title: "Trending on Netflix", items: engine.netflixTrending.filter { $0.mediaType == .tvShow }) { item in
                selectedItem = item
            }
        }
        if !engine.disneyTrending.isEmpty {
            TVContentRowView(title: "Trending on Disney+", items: engine.disneyTrending.filter { $0.mediaType == .tvShow }) { item in
                selectedItem = item
            }
        }
        if !engine.appleTVTrending.isEmpty {
            TVContentRowView(title: "Trending on Apple TV+", items: engine.appleTVTrending.filter { $0.mediaType == .tvShow }) { item in
                selectedItem = item
            }
        }
    }
    
    // MARK: - Streaming Sections
    
    @ViewBuilder
    private var streamingDiscoverySections: some View {
        let displayItems = providerItems.isEmpty ? engine.streamingItems : providerItems
        TVContentRowView(title: "Trending on \(selectedProvider.name)", items: displayItems) { item in
            selectedItem = item
        }
        
        let topRated = displayItems.filter { $0.rating >= 7.8 }
        if !topRated.isEmpty {
            TVContentRowView(title: "Highest Rated on \(selectedProvider.name)", items: topRated) { item in
                selectedItem = item
            }
        }
    }
    
    private func loadProviderContent(_ provider: StreamingProvider) async {
        isLoadingProvider = true
        providerItems = await tmdb.fetchStreaming(provider: provider)
        isLoadingProvider = false
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
