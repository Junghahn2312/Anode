import SwiftUI
import Combine

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var heroIndex: Int = 0
    @State private var isUserInteracting: Bool = false
    @State private var selectedItem: MediaItem?
    @State private var heroAvailability: WatchAvailability?
    
    private let timer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    private var heroPool: [MediaItem] {
        if !engine.heroSpotlights.isEmpty {
            return engine.heroSpotlights
        }
        return Array((engine.cinemaNow + engine.trendingItems).prefix(6))
    }
    
    private var spotlightHero: MediaItem? {
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroIndex % heroPool.count]
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack(alignment: .topLeading) {
                // Continuous Cinematic Dark Base (Zero Black Bar Cuts)
                Color(red: 0.04, green: 0.04, blue: 0.05)
                    .ignoresSafeArea()
                
                // Ambient Atmospheric Glow Spanning Full Screen Height
                if let hero = spotlightHero {
                    CachedAsyncImage(url: hero.backdropURL(size: "w780"), contentMode: .fill)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        .blur(radius: 110)
                        .opacity(0.32)
                        .clipped()
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.6), value: hero.id)
                }
                
                // Unified Root Vertical ScrollView (Continuous Natural Flow)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. Massive Hero Spotlight Section (~840pt height, ~78-80% screen)
                        if let hero = spotlightHero {
                            heroShowcaseSection(hero: hero, screenGeo: screenGeo)
                        } else {
                            Color.clear
                                .frame(width: screenGeo.size.width, height: 840)
                        }
                        
                        // 2. Content Rows with Expanding Cards & Inline Detail Strips (Image 2)
                        contentRowsSection
                    }
                    .padding(.bottom, 120)
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
        }
        .onReceive(timer) { _ in
            if !isUserInteracting && !heroPool.isEmpty {
                withAnimation(.easeInOut(duration: 0.8)) {
                    heroIndex = (heroIndex + 1) % heroPool.count
                }
            }
        }
        .task(id: spotlightHero?.id) {
            if let hero = spotlightHero {
                heroAvailability = await engine.fetchAvailability(for: hero)
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Massive Hero Showcase Section (~840pt, 80% screen, peeking first row below)
    
    private func heroShowcaseSection(hero: MediaItem, screenGeo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Full-Bleed 4K Backdrop Artwork
            CachedAsyncImage(url: hero.backdropURL(size: "original"), contentMode: .fill)
                .frame(width: screenGeo.size.width, height: 840, alignment: .top)
                .clipped()
                .overlay(
                    // Left-to-right gradient for typography readability
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.96), location: 0.0),
                            .init(color: Color.black.opacity(0.82), location: 0.38),
                            .init(color: Color.black.opacity(0.32), location: 0.68),
                            .init(color: Color.clear, location: 0.94)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    // Bottom fluid fade seamlessly dissolving into first row below
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.clear, location: 0.45),
                            .init(color: Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.35), location: 0.65),
                            .init(color: Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.80), location: 0.84),
                            .init(color: Color(red: 0.04, green: 0.04, blue: 0.05), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .id(hero.id)
                .transition(.opacity)
            
            // Hero Typography, Metadata & Action Controls
            VStack(alignment: .leading, spacing: 14) {
                // Category & Availability Frosted Glass Badges
                HStack(spacing: 12) {
                    Text("ANODE SPOTLIGHT")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.0)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                    
                    if hero.inCinemas {
                        Text("IN CINEMAS NOW")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.0)
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1)
                            )
                    } else if let avail = heroAvailability, let primarySub = avail.subscriptions.first {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(primarySub.brandColor)
                                .frame(width: 7, height: 7)
                            Text("STREAMING ON \(primarySub.name.uppercased())")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.8)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(primarySub.brandColor.opacity(0.45), lineWidth: 1)
                        )
                    }
                }
                
                // Grand Title
                Text(hero.title)
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 3)
                
                // Metadata Line
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
                    
                    if !hero.formattedRating.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        RatingBadge(rating: hero.formattedRating)
                    }
                }
                
                // Synopsis (3 lines)
                if !hero.overview.isEmpty {
                    Text(hero.overview)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .lineSpacing(4)
                        .frame(maxWidth: 820, alignment: .leading)
                        .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
                }
                
                // Primary & Secondary Action Buttons
                HStack(spacing: 16) {
                    Button {
                        selectedItem = hero
                    } label: {
                        TVHomePrimaryHeroButtonLabel(title: hero.mediaType == .tvShow ? "Go to Series" : "View Details")
                    }
                    .buttonStyle(.tvCard)
                    
                    Button {
                        watchlist.toggleWatchlist(item: hero)
                    } label: {
                        TVHomeSecondaryBookmarkButtonLabel(isBookmarked: watchlist.contains(id: hero.id))
                    }
                    .buttonStyle(.tvCard)
                }
                .padding(.top, 4)
                
                // Carousel Page Indicator Dots
                let totalDots = min(heroPool.count, 8)
                let currentIndex = heroIndex % max(1, heroPool.count)
                HStack(spacing: 8) {
                    ForEach(0..<totalDots, id: \.self) { idx in
                        let isActive = (currentIndex % totalDots) == idx
                        Capsule()
                            .fill(isActive ? Color.white : Color.white.opacity(0.35))
                            .frame(width: isActive ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isActive)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.top, 4)
            }
            .id(hero.id)
            .transition(.opacity)
            .padding(.horizontal, 60)
            .padding(.bottom, 24)
        }
        .frame(width: screenGeo.size.width, height: 840)
        .animation(.easeInOut(duration: 0.35), value: hero.id)
    }
    
    // MARK: - Content Rows Section with Expanding Cards & Inline Detail Strips
    
    @ViewBuilder
    private var contentRowsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // First Row: Popular (16:9 Landscape - Peeks in at bottom edge when at top of page)
            let popularItems = Array((engine.popularMovies + engine.popularTV).prefix(10))
            if !popularItems.isEmpty {
                TVLandscapeRowView(
                    title: "Popular",
                    items: popularItems
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // My Watchlist (if populated)
            if !watchlist.items.isEmpty {
                TVContentRowView(
                    title: "My List",
                    items: watchlist.items
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Top 10 Today (Large Numeral Row)
            if !engine.topTen.isEmpty {
                TVTopTenRowView(
                    title: "Top 10 Today",
                    items: engine.topTen
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Trending Now
            if !engine.trendingItems.isEmpty {
                TVContentRowView(
                    title: "Trending Now",
                    items: engine.trendingItems
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Now in Cinemas
            if !engine.cinemaNow.isEmpty {
                TVContentRowView(
                    title: "Now in Cinemas",
                    items: engine.cinemaNow,
                    showCinemaBadge: true
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Trending on Netflix
            if !engine.netflixTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Netflix",
                    items: engine.netflixTrending
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Trending on Disney+
            if !engine.disneyTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Disney+",
                    items: engine.disneyTrending
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Trending on Prime Video
            if !engine.primeTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Prime Video",
                    items: engine.primeTrending
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Trending on Apple TV+
            if !engine.appleTVTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Apple TV+",
                    items: engine.appleTVTrending
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Popular Movies
            if !engine.popularMovies.isEmpty {
                TVContentRowView(
                    title: "Popular Movies",
                    items: engine.popularMovies
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Coming Soon to Theatres (16:9 Landscape Variety Row)
            if !engine.cinemaUpcoming.isEmpty {
                TVLandscapeRowView(
                    title: "Coming Soon to Theatres",
                    items: engine.cinemaUpcoming
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
            
            // Critically Acclaimed
            if !engine.topRated.isEmpty {
                TVContentRowView(
                    title: "Critically Acclaimed",
                    items: engine.topRated
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
            }
        }
    }
}

// MARK: - Focus-Reactive Button Labels

private struct TVHomePrimaryHeroButtonLabel: View {
    let title: String
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .black))
            Text(title)
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.24))
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

private struct TVHomeSecondaryBookmarkButtonLabel: View {
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
                .fill(isFocused ? Color(white: 0.35) : Color.white.opacity(0.16))
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
