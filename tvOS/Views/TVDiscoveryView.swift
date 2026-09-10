import SwiftUI

public struct TVDiscoveryView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
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
    
    private var featuredHero: MediaItem? {
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 38) {
                // Top Header & Filter Pills
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Text("DISCOVERY")
                            .font(.system(size: 13, weight: .black))
                            .tracking(2.2)
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.18)))
                        
                        Text("GLOBAL ENTERTAINMENT")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text("Explore Entertainment")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Filter Selector
                    HStack(spacing: 14) {
                        ForEach(DiscoveryFilter.allCases) { filter in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedFilter = filter
                                }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 16, weight: selectedFilter == filter ? .bold : .medium))
                                    .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(selectedFilter == filter ? Color.white.opacity(0.24) : Color(white: 0.14))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 60)
                .padding(.top, 48)
                
                // Grand Featured Spotlight Hero (Never cut off with top alignment)
                if let hero = featuredHero {
                    discoveryHero(hero)
                        .padding(.horizontal, 60)
                }
                
                // Dynamic Content Rows Based on Selected Filter
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
            .padding(.bottom, 90)
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
    
    // MARK: - Grand Discovery Hero (Top-aligned 4K Artwork)
    
    private func discoveryHero(_ item: MediaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            ZStack(alignment: .bottomLeading) {
                // 4K Backdrop aligned to top so character faces are never cropped
                CachedAsyncImage(url: item.backdropURL(size: "original"), contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 520, alignment: .top)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                // Left gradient mask for text readability
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.92), location: 0.0),
                        .init(color: Color.black.opacity(0.70), location: 0.42),
                        .init(color: Color.clear, location: 0.85)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                // Bottom gradient mask
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.35),
                        .init(color: Color.black.opacity(0.85), location: 0.90),
                        .init(color: Color.black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                // Hero Overlay Content
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Text(item.mediaType == .movie ? "FEATURED FILM" : "FEATURED SERIES")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                        
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                        }
                    }
                    
                    Text(item.title)
                        .font(.system(size: 46, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 10) {
                        if !item.yearString.isEmpty {
                            Text(item.yearString)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        if let genre = item.genreNames.first {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text(genre)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Text(item.overview)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(3)
                        .lineSpacing(3)
                        .frame(maxWidth: 760, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16, weight: .bold))
                            Text("View Details")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.25)))
                    }
                    .padding(.top, 4)
                }
                .padding(40)
            }
        }
        .buttonStyle(.tvCard)
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
        VStack(alignment: .leading, spacing: 20) {
            // Streaming Provider Pills
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(StreamingProvider.allCases, id: \.id) { provider in
                        Button {
                            selectedProvider = provider
                            Task { await loadProviderContent(provider) }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(provider.brandColor)
                                    .frame(width: 10, height: 10)
                                
                                Text(provider.name)
                                    .font(.system(size: 15, weight: selectedProvider == provider ? .bold : .medium))
                                    .foregroundColor(selectedProvider == provider ? .white : .white.opacity(0.7))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(selectedProvider == provider ? provider.brandColor.opacity(0.35) : Color(white: 0.14))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 8)
            }
            
            let displayItems = providerItems.isEmpty ? engine.streamingItems : providerItems
            discoveryRow(title: "Trending on \(selectedProvider.name)", items: displayItems)
            
            let topRated = displayItems.filter { $0.rating >= 7.8 }
            if !topRated.isEmpty {
                discoveryRow(title: "Highest Rated on \(selectedProvider.name)", items: topRated)
            }
        }
    }
    
    private func loadProviderContent(_ provider: StreamingProvider) async {
        isLoadingProvider = true
        providerItems = await tmdb.fetchStreaming(provider: provider)
        isLoadingProvider = false
    }
    
    // MARK: - Discovery Row (Never cut off posters with 24pt vertical padding)
    
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
                            )
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
        }
    }
}
