import SwiftUI

public struct DiscoverView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    @State private var selectedItem: MediaItem?
    
    public init() {}
    
    private var heroItem: MediaItem? {
        engine.topTen.first ?? engine.cinemaMovies.first
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    // Big Hero Spotlight Banner (Netflix style)
                    if let hero = heroItem {
                        heroBanner(hero: hero)
                    }
                    
                    // Top 10 in Cinema & Streaming (Netflix Giant Numbers)
                    if !engine.topTen.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Top 10 Today")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(Array(engine.topTen.enumerated()), id: \.element.id) { index, item in
                                        Button {
                                            selectedItem = item
                                        } label: {
                                            TopTenCardView(rank: index + 1, item: item, width: 130)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Streaming Platforms
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Streaming Platforms")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(StreamingProvider.allMajor) { provider in
                                    Button {
                                        engine.selectedProvider = provider
                                    } label: {
                                        StreamingPlatformTileView(provider: provider, width: 190)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                    
                    // Curated Photographic Genres
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Genres")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(GenreCategory.allCurated) { genre in
                                    GenrePhotoCardView(genre: genre, width: 190)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                    }
                    
                    // In Theaters Now
                    discoveryRow(title: "In Theaters Now", items: engine.cinemaMovies)
                    
                    // Trending Everywhere
                    discoveryRow(title: "Trending Everywhere", items: engine.trendingItems)
                    
                    // New Releases
                    discoveryRow(title: "New Releases", items: engine.newReleases)
                    
                    // Critically Acclaimed
                    discoveryRow(title: "Critically Acclaimed", items: engine.topRated)
                    
                    // Upcoming Radar
                    discoveryRow(title: "Upcoming Radar", items: engine.upcoming)
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(item: $selectedItem) { item in
                MediaDetailView(item: item)
            }
            .refreshable {
                await engine.loadAll()
            }
        }
    }
    
    // MARK: - Big Hero Banner
    
    @ViewBuilder
    private func heroBanner(hero: MediaItem) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Backdrop Artwork
                CachedAsyncImage(url: hero.backdropURL(size: "w1280"))
                    .frame(width: geo.size.width, height: 380)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.1), location: 0.0),
                                .init(color: Color.black.opacity(0.5), location: 0.5),
                                .init(color: Color.black.opacity(0.95), location: 0.85),
                                .init(color: Color.black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Hero Content Overlay
                VStack(alignment: .leading, spacing: 10) {
                    // Header badge
                    HStack(spacing: 8) {
                        Text("FEATURED SPOTLIGHT")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.8)
                            .foregroundColor(Color.red)
                        
                        if let rank = hero.rank {
                            Text("#\(rank) Today")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(hero.title)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    // Metadata
                    HStack(spacing: 8) {
                        if let genre = hero.genreNames.first {
                            Text(genre)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        if !hero.yearString.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text(hero.yearString)
                                .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        }
                        if !hero.formattedRuntime.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text(hero.formattedRuntime)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        if !hero.formattedRating.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            RatingBadge(rating: hero.formattedRating)
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        if let trailer = hero.trailers.first, let url = trailer.youtubeURL {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Play Trailer")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: watchlist.contains(id: hero.id) ? "checkmark" : "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(watchlist.contains(id: hero.id) ? "Saved" : "Watchlist")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        
                        Button {
                            selectedItem = hero
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .frame(width: geo.size.width, alignment: .leading)
            }
        }
        .frame(height: 380)
    }
    
    // MARK: - Standard Poster Row
    
    @ViewBuilder
    private func discoveryRow(title: String, items: [MediaItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                PosterCardView(item: item, width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}
