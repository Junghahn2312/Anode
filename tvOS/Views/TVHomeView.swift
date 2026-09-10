import SwiftUI
import Combine

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var focusedItem: MediaItem?
    @State private var heroIndex: Int = 0
    @State private var isUserInteracting: Bool = false
    @State private var selectedItem: MediaItem?
    @State private var heroAvailability: WatchAvailability?
    
    private let timer = Timer.publish(every: 7.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    private var heroPool: [MediaItem] {
        if !engine.heroSpotlights.isEmpty {
            return engine.heroSpotlights
        }
        return Array((engine.cinemaNow + engine.trendingItems).prefix(6))
    }
    
    private var currentHero: MediaItem? {
        if let focusedItem {
            return focusedItem
        }
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroIndex % heroPool.count]
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack(alignment: .topLeading) {
                // Ambient Pure Black Background
                Color.black.ignoresSafeArea()
                
                // 4K Backdrop in top 52% of the screen
                if let hero = currentHero {
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(url: hero.backdropURL(size: "original"))
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.52)
                            .clipped()
                            .id(hero.id)
                            .transition(.opacity)
                        
                        // Left-to-right gradient for crisp text legibility
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.96), location: 0.0),
                                .init(color: Color.black.opacity(0.78), location: 0.38),
                                .init(color: Color.black.opacity(0.32), location: 0.65),
                                .init(color: Color.clear, location: 0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.52)
                        
                        // Top-to-bottom gradient fading cleanly into solid black
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.20),
                                .init(color: Color.black.opacity(0.40), location: 0.55),
                                .init(color: Color.black.opacity(0.85), location: 0.82),
                                .init(color: Color.black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.52)
                    }
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.32), value: hero.id)
                }
                
                // Foreground Vertical Layout:
                // 1. Pinned Hero Section (stationary at top, height ~42% of screen)
                // 2. Scrollable Rows (scrolls vertically beneath hero, height ~58% of screen)
                VStack(alignment: .leading, spacing: 0) {
                    if let hero = currentHero {
                        heroMetadataView(hero)
                            .padding(.horizontal, 60)
                            .padding(.top, 36)
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.42, alignment: .bottomLeading)
                            .animation(.easeInOut(duration: 0.28), value: hero.id)
                    } else {
                        Color.clear
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.42)
                    }
                    
                    // Scrollable Rows Section
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 34) {
                            // Top 10 Today (Large Numeral Row)
                            if !engine.topTen.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Top 10 Today")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 60)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 36) {
                                            ForEach(Array(engine.topTen.enumerated()), id: \.element.id) { index, item in
                                                Button {
                                                    selectedItem = item
                                                } label: {
                                                    TopTenCardView(rank: index + 1, item: item, width: 175) { focused in
                                                        handleCardFocus(focused)
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
                            
                            // Trending Now
                            if !engine.trendingItems.isEmpty {
                                contentRow(
                                    title: "Trending Now",
                                    items: engine.trendingItems
                                )
                            }
                            
                            // Now in Cinemas
                            if !engine.cinemaNow.isEmpty {
                                contentRow(
                                    title: "Now in Cinemas",
                                    items: engine.cinemaNow,
                                    showCinemaBadge: true
                                )
                            }
                            
                            // Trending on Netflix
                            if !engine.netflixTrending.isEmpty {
                                contentRow(
                                    title: "Trending on Netflix",
                                    items: engine.netflixTrending
                                )
                            }
                            
                            // Trending on Disney+
                            if !engine.disneyTrending.isEmpty {
                                contentRow(
                                    title: "Trending on Disney+",
                                    items: engine.disneyTrending
                                )
                            }
                            
                            // Trending on Prime Video
                            if !engine.primeTrending.isEmpty {
                                contentRow(
                                    title: "Trending on Prime Video",
                                    items: engine.primeTrending
                                )
                            }
                            
                            // Trending on Apple TV+
                            if !engine.appleTVTrending.isEmpty {
                                contentRow(
                                    title: "Trending on Apple TV+",
                                    items: engine.appleTVTrending
                                )
                            }
                            
                            // Popular Movies
                            if !engine.popularMovies.isEmpty {
                                contentRow(
                                    title: "Popular Movies",
                                    items: engine.popularMovies
                                )
                            }
                            
                            // Coming Soon to Theatres (16:9 Landscape Variety Row)
                            if !engine.cinemaUpcoming.isEmpty {
                                landscapeRow(
                                    title: "Coming Soon to Theatres",
                                    items: engine.cinemaUpcoming
                                )
                            }
                            
                            // Critically Acclaimed
                            if !engine.topRated.isEmpty {
                                contentRow(
                                    title: "Critically Acclaimed",
                                    items: engine.topRated
                                )
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 90)
                    }
                    .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.58)
                }
            }
        }
        .onReceive(timer) { _ in
            if !isUserInteracting && focusedItem == nil && !heroPool.isEmpty {
                withAnimation(.easeInOut(duration: 0.8)) {
                    heroIndex = (heroIndex + 1) % heroPool.count
                }
            }
        }
        .task(id: currentHero?.id) {
            if let currentHero {
                heroAvailability = await engine.fetchAvailability(for: currentHero)
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Hero Metadata View
    
    private func heroMetadataView(_ hero: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category & Availability Pill
            HStack(spacing: 12) {
                Text("ANODE SPOTLIGHT")
                    .font(.system(size: 12, weight: .black))
                    .tracking(2.2)
                    .foregroundColor(.red)
                
                if hero.inCinemas {
                    Text("IN CINEMAS NOW")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.0)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.85)))
                } else if let avail = heroAvailability, let primarySub = avail.subscriptions.first {
                    Text("STREAMING ON \(primarySub.name.uppercased())")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(primarySub.brandColor.opacity(0.65)))
                } else if let avail = heroAvailability, let rent = avail.rentOptions.first {
                    Text("RENT FROM \(rent.price)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                }
            }
            
            // Hero Title
            Text(hero.title)
                .font(.system(size: 42, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
            
            // Metadata Line
            HStack(spacing: 12) {
                if let genre = hero.genreNames.first {
                    Text(genre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !hero.yearString.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(hero.yearString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !hero.formattedRuntime.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(hero.formattedRuntime)
                        .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(2)
                .lineSpacing(3)
                .frame(maxWidth: 760, alignment: .leading)
                .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
            
            // Action Buttons
            HStack(spacing: 18) {
                Button {
                    selectedItem = hero
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .bold))
                        Text("View Details")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                }
                
                Button {
                    watchlist.toggleWatchlist(item: hero)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: watchlist.contains(id: hero.id) ? "checkmark" : "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text(watchlist.contains(id: hero.id) ? "In My List" : "Add to My List")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                }
                
                if let trailer = hero.trailers.first, let url = trailer.youtubeURL {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Watch Trailer")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(alignment: .bottomLeading)
    }
    
    // MARK: - Standard Content Row
    
    private func contentRow(title: String, items: [MediaItem], showCinemaBadge: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - Landscape Row (16:9)
    
    private func landscapeRow(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            TVLandscapeCardView(
                                item: item,
                                width: 380,
                                subtitle: item.releaseDate ?? "Coming Soon"
                            ) { focused in
                                handleCardFocus(focused)
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
    
    private func handleCardFocus(_ item: MediaItem) {
        isUserInteracting = true
        if focusedItem?.id != item.id {
            withAnimation(.easeInOut(duration: 0.28)) {
                focusedItem = item
            }
        }
    }
}
