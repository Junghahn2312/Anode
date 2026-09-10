import SwiftUI

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var heroItem: MediaItem?
    @State private var ambientBackdropURL: URL?
    @State private var selectedItem: MediaItem?
    @State private var activeGenre: GenreCategory?
    
    public init() {}
    
    private var currentHero: MediaItem? {
        heroItem ?? engine.topTen.first ?? engine.cinemaMovies.first
    }
    
    private var activeBackdrop: URL? {
        ambientBackdropURL ?? currentHero?.backdropURL(size: "original")
    }
    
    public var body: some View {
        ZStack {
            // Full-screen Dynamic Ambient Backdrop (Netflix style)
            if let activeBackdrop {
                CachedAsyncImage(url: activeBackdrop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.3), location: 0.0),
                                .init(color: Color.black.opacity(0.65), location: 0.4),
                                .init(color: Color.black.opacity(0.92), location: 0.75),
                                .init(color: Color.black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .animation(.easeInOut(duration: 0.35), value: activeBackdrop)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {
                    // Top Hero Section
                    heroSection
                    
                    // Top 10 in Cinema & Streaming (Netflix style giant numerals)
                    if !engine.topTen.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Top 10 Today")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 40) {
                                    ForEach(Array(engine.topTen.enumerated()), id: \.element.id) { index, item in
                                        Button {
                                            selectedItem = item
                                        } label: {
                                            TopTenCardView(rank: index + 1, item: item, width: 175) { focused in
                                                self.heroItem = focused
                                                self.ambientBackdropURL = focused.backdropURL(size: "original")
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 60)
                                .padding(.vertical, 16)
                            }
                        }
                    }
                    
                    // Streaming Platforms (Netflix, Apple TV+, Prime Video, Max, Disney+)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Streaming Platforms")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 60)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                ForEach(StreamingProvider.allMajor) { provider in
                                    Button {
                                        engine.selectedProvider = provider
                                    } label: {
                                        StreamingPlatformTileView(provider: provider, width: 280) { focusedProvider in
                                            self.ambientBackdropURL = StreamingPlatformTileView.defaultBackdrop(for: focusedProvider)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // Curated Photographic Genres
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Genres")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 60)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                ForEach(GenreCategory.allCurated) { genre in
                                    Button {
                                        self.activeGenre = genre
                                    } label: {
                                        GenrePhotoCardView(genre: genre, width: 280) { focusedGenre in
                                            self.ambientBackdropURL = focusedGenre.heroBackdropURL
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, 12)
                        }
                    }
                    
                    // In Theaters Now
                    tvMediaSection(title: "In Theaters Now", items: engine.cinemaMovies)
                    
                    // Trending Everywhere
                    tvMediaSection(title: "Trending Everywhere", items: engine.trendingItems)
                    
                    // New Releases
                    tvMediaSection(title: "New Releases", items: engine.newReleases)
                    
                    // Critically Acclaimed
                    tvMediaSection(title: "Critically Acclaimed", items: engine.topRated)
                    
                    // Upcoming Radar
                    tvMediaSection(title: "Upcoming Radar", items: engine.upcoming)
                }
                .padding(.top, 40)
                .padding(.bottom, 80)
            }
        }
        .sheet(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Big Hero Spotlight
    
    @ViewBuilder
    private var heroSection: some View {
        if let hero = currentHero {
            VStack(alignment: .leading, spacing: 20) {
                // Top Brand & Category Tag
                HStack(spacing: 12) {
                    Text("ANODE SPOTLIGHT")
                        .font(.system(size: 13, weight: .black))
                        .tracking(2.5)
                        .foregroundColor(Color.red)
                    
                    if let rank = hero.rank {
                        Text("#\(rank) in Top 10")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                // Hero Title
                Text(hero.title)
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
                
                // Metadata Line: Genre • Year • Runtime • Rating • Cert
                HStack(spacing: 12) {
                    if let genre = hero.genreNames.first {
                        Text(genre)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if !hero.yearString.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(hero.yearString)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if !hero.formattedRuntime.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(hero.formattedRuntime)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if let cert = hero.certification {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(cert)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    }
                    
                    if !hero.formattedRating.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        RatingBadge(rating: hero.formattedRating)
                    }
                }
                
                // Synopsis
                Text(hero.overview)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .lineSpacing(5)
                    .frame(maxWidth: 800, alignment: .leading)
                    .shadow(color: Color.black.opacity(0.8), radius: 4, x: 0, y: 2)
                
                // Hero Action Buttons (Netflix Style)
                HStack(spacing: 18) {
                    if let trailer = hero.trailers.first, let url = trailer.youtubeURL {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Play Trailer")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                        }
                    }
                    
                    Button {
                        watchlist.toggleWatchlist(item: hero)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: watchlist.contains(id: hero.id) ? "checkmark" : "plus")
                                .font(.system(size: 18, weight: .bold))
                            Text(watchlist.contains(id: hero.id) ? "In Watchlist" : "Add to Watchlist")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                    
                    Button {
                        selectedItem = hero
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18, weight: .bold))
                            Text("Details")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 60)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Section Row
    
    @ViewBuilder
    private func tvMediaSection(title: String, items: [MediaItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 36) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                TVMediaCardView(item: item, width: 220) { focusedItem in
                                    self.heroItem = focusedItem
                                    self.ambientBackdropURL = focusedItem.backdropURL(size: "original")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}
