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
                                .init(color: Color.black.opacity(0.85), location: 0.36),
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
                
                // Foreground Vertical Layout:
                // 1. Pinned Hero Section (stationary at top, grand height ~48% of screen)
                // 2. Scrollable Rows (scrolls vertically beneath hero, height ~52% of screen)
                VStack(alignment: .leading, spacing: 0) {
                    if let hero = currentHero {
                        heroMetadataView(hero)
                            .padding(.horizontal, 60)
                            .padding(.top, 44)
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.48, alignment: .bottomLeading)
                            .animation(.easeInOut(duration: 0.28), value: hero.id)
                    } else {
                        Color.clear
                            .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.48)
                    }
                    
                    // Scrollable Rows Section
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 36) {
                            // My Watchlist (if populated)
                            if !watchlist.items.isEmpty {
                                contentRow(
                                    title: "My List",
                                    items: watchlist.items
                                )
                            }
                            
                            // Popular (16:9 Landscape - Image 2)
                            let popularItems = Array((engine.popularMovies + engine.popularTV).prefix(10))
                            if !popularItems.isEmpty {
                                landscapeRow(
                                    title: "Popular",
                                    items: popularItems
                                )
                            }
                            
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
                                                .buttonStyle(.tvCard)
                                            }
                                        }
                                        .padding(.horizontal, 60)
                                        .padding(.vertical, 24)
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
                    .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.52)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
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
            // Category & Availability Frosted Glass Pills
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("ANODE SPOTLIGHT")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.0)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
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
                            Capsule()
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
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
                        Capsule()
                            .stroke(primarySub.brandColor.opacity(0.45), lineWidth: 1)
                    )
                } else if let avail = heroAvailability, let rent = avail.rentOptions.first {
                    Text("RENT FROM \(rent.price)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
            }
            
            // Hero Title
            Text(hero.title)
                .font(.system(size: 50, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2)
                .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
            
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
                
                if let cert = hero.certification {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(cert)
                        .font(.system(size: 13, weight: .bold))
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
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.84))
                .lineLimit(3)
                .lineSpacing(4)
                .frame(maxWidth: 820, alignment: .leading)
                .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
            
            // Action Buttons (Matching Image 2)
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
            
            // Frosted Glass Carousel Page Indicator Dots (Matching Image 2)
            let totalDots = min(heroPool.count, 8)
            let currentIndex = focusedItem == nil ? (heroIndex % max(1, heroPool.count)) : (heroPool.firstIndex(where: { $0.id == focusedItem?.id }) ?? 0)
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
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.top, 6)
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
    
    // MARK: - Landscape Row (16:9)
    
    private func landscapeRow(title: String, items: [MediaItem]) -> some View {
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
                            TVLandscapeCardView(
                                item: item,
                                width: 380,
                                subtitle: item.releaseDate ?? "Coming Soon"
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
        isUserInteracting = true
        if focusedItem?.id != item.id {
            withAnimation(.easeInOut(duration: 0.28)) {
                focusedItem = item
            }
        }
    }
}

// MARK: - Dedicated Focusable Hero Button Labels

private struct TVHomePrimaryHeroButtonLabel: View {
    let title: String
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color(white: 0.85) : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: Color.white.opacity(isFocused ? 0.35 : 0.0), radius: isFocused ? 12 : 0, x: 0, y: 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}

private struct TVHomeSecondaryBookmarkButtonLabel: View {
    let isBookmarked: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color(white: 0.85) : Color.white.opacity(0.2), lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}
