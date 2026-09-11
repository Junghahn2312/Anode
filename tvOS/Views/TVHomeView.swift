import SwiftUI
import Combine

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var heroIndex: Int = 0
    @State private var isUserInteracting: Bool = false
    @State private var selectedItem: MediaItem?
    @State private var heroAvailability: WatchAvailability?
    @State private var hoveredItem: MediaItem? = nil
    @State private var activeRowIndex: Int = -1
    
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
    
    private var isCarouselOutOfView: Bool {
        activeRowIndex >= 1
    }
    
    private var activeBackgroundItem: MediaItem? {
        hoveredItem ?? spotlightHero
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background (100% Viewport, Zero Black Spaces)
                rootBackground(screenWidth: screenWidth, screenHeight: screenHeight)
                
                // Unified Root Vertical ScrollView (Continuous Natural Flow)
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 1. Full-Screen Hero Spotlight Section (100% Viewport, Zero Black Bars)
                            if let hero = spotlightHero {
                                heroShowcaseSection(hero: hero, screenWidth: screenWidth, screenHeight: screenHeight)
                                    .id("heroSection")
                            } else {
                                Color.clear
                                    .frame(width: screenWidth, height: screenHeight)
                                    .id("heroSection")
                            }
                            
                            // 2. Content Rows with Dynamic Expanding Cards & Inline Detail Strips (Image 2)
                            contentRowsSection
                                .offset(y: -260)
                        }
                        .padding(.bottom, 260)
                    }
                    .coordinateSpace(name: "homeScroll")
                    .onChange(of: activeRowIndex) { _, newIndex in
                        if newIndex == 0 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("row-0", anchor: UnitPoint(x: 0.5, y: 0.76))
                            }
                        } else if newIndex > 0 {
                            // Selected row sits higher on screen (not at top, but higher - Y ~ 260)
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("row-\(newIndex)", anchor: UnitPoint(x: 0.5, y: 0.48))
                            }
                        } else if newIndex == -1 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("heroSection", anchor: .top)
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
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
    
    // MARK: - Dynamic Full-Screen Background (Zero Black Spaces)
    
    private func rootBackground(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack {
            // Dark base color to guarantee zero harsh flashes
            Color(red: 0.04, green: 0.04, blue: 0.05)
                .ignoresSafeArea()
            
            if let bgItem = activeBackgroundItem {
                let backdropURL = bgItem.backdropURL(size: "w1280") ?? bgItem.posterURL(size: "original")
                ZStack {
                    CachedAsyncImage(
                        url: backdropURL,
                        contentMode: .fill
                    )
                    .frame(width: screenWidth, height: screenHeight)
                    .clipped()
                    .blur(radius: isCarouselOutOfView ? 40 : 0)
                    .id(bgItem.id)
                    .transition(.opacity)
                    
                    // Dark scrim for list contrast when carousel is out of view
                    Color.black.opacity(isCarouselOutOfView ? 0.42 : 0.0)
                    
                    // Subtle vignettes active when carousel hero is in view
                    Group {
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
                        
                        // Soft top vignette for tab bar readability
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.70), location: 0.0),
                                .init(color: Color.clear, location: 0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Soft bottom fade allowing artwork to shine through peeking row
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.45),
                                .init(color: Color.black.opacity(0.35), location: 0.72),
                                .init(color: Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.75), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .opacity(isCarouselOutOfView ? 0.0 : 1.0)
                }
                .animation(.easeInOut(duration: 0.55), value: bgItem.id)
                .animation(.easeInOut(duration: 0.55), value: isCarouselOutOfView)
            }
        }
        .frame(width: screenWidth, height: screenHeight)
        .ignoresSafeArea()
    }
    
    // MARK: - Massive Hero Showcase Section (~840pt, 80% screen, peeking first row below)
    
    private func heroShowcaseSection(hero: MediaItem, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: screenWidth, height: screenHeight)
            
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
                        TVHomePrimaryHeroButtonLabel(
                            title: hero.mediaType == .tvShow ? "Go to Series" : "View Details"
                        ) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                self.hoveredItem = nil
                                self.activeRowIndex = -1
                            }
                        }
                    }
                    .buttonStyle(.tvCard)
                    
                    Button {
                        watchlist.toggleWatchlist(item: hero)
                    } label: {
                        TVHomeSecondaryBookmarkButtonLabel(
                            isBookmarked: watchlist.contains(id: hero.id)
                        ) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                self.hoveredItem = nil
                                self.activeRowIndex = -1
                            }
                        }
                    }
                    .buttonStyle(.tvCard)
                }
                .focusSection()
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
                            .animation(.spring(response: 0.40, dampingFraction: 0.85), value: isActive)
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
            .padding(.bottom, 280)
        }
        .frame(width: screenWidth, height: screenHeight)
        .animation(.easeInOut(duration: 0.45), value: hero.id)
    }
    
    // MARK: - Content Rows Section with Expanding Cards & Inline Detail Strips
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.45)) {
            self.hoveredItem = item
        }
        if activeRowIndex != rowIndex {
            self.activeRowIndex = rowIndex
        }
    }
    
    @ViewBuilder
    private var contentRowsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // First Row: Popular (16:9 Landscape - Peeks in at bottom edge when at top of page)
            let popularItems = Array((engine.popularMovies + engine.popularTV).prefix(10))
            if !popularItems.isEmpty {
                TVLandscapeRowView(
                    title: "Popular",
                    items: popularItems,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-0")
            }
            
            // My Watchlist (if populated)
            if !watchlist.items.isEmpty {
                TVContentRowView(
                    title: "My List",
                    items: watchlist.items,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-1")
            }
            
            // Top 10 Today (Large Numeral Row)
            if !engine.topTen.isEmpty {
                TVTopTenRowView(
                    title: "Top 10 Today",
                    items: engine.topTen,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-2")
            }
            
            // Trending Now
            if !engine.trendingItems.isEmpty {
                TVContentRowView(
                    title: "Trending Now",
                    items: engine.trendingItems,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-3")
            }
            
            // Now in Cinemas
            if !engine.cinemaNow.isEmpty {
                TVContentRowView(
                    title: "Now in Cinemas",
                    items: engine.cinemaNow,
                    showCinemaBadge: true,
                    onHover: { handleRowHover($0, rowIndex: 4) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-4")
            }
            
            // Trending on Netflix
            if !engine.netflixTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Netflix",
                    items: engine.netflixTrending,
                    onHover: { handleRowHover($0, rowIndex: 5) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-5")
            }
            
            // Trending on Disney+
            if !engine.disneyTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Disney+",
                    items: engine.disneyTrending,
                    onHover: { handleRowHover($0, rowIndex: 6) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-6")
            }
            
            // Trending on Prime Video
            if !engine.primeTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Prime Video",
                    items: engine.primeTrending,
                    onHover: { handleRowHover($0, rowIndex: 7) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-7")
            }
            
            // Trending on Apple TV+
            if !engine.appleTVTrending.isEmpty {
                TVContentRowView(
                    title: "Trending on Apple TV+",
                    items: engine.appleTVTrending,
                    onHover: { handleRowHover($0, rowIndex: 8) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-8")
            }
            
            // Popular Movies
            if !engine.popularMovies.isEmpty {
                TVContentRowView(
                    title: "Popular Movies",
                    items: engine.popularMovies,
                    onHover: { handleRowHover($0, rowIndex: 9) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-9")
            }
            
            // Coming Soon to Theatres (16:9 Landscape Variety Row)
            if !engine.cinemaUpcoming.isEmpty {
                TVLandscapeRowView(
                    title: "Coming Soon to Theatres",
                    items: engine.cinemaUpcoming,
                    onHover: { handleRowHover($0, rowIndex: 10) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-10")
            }
            
            // Critically Acclaimed
            if !engine.topRated.isEmpty {
                TVContentRowView(
                    title: "Critically Acclaimed",
                    items: engine.topRated,
                    onHover: { handleRowHover($0, rowIndex: 11) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-11")
            }
        }
    }
}

// MARK: - Focus-Reactive Button Labels

private struct TVHomePrimaryHeroButtonLabel: View {
    let title: String
    var onFocus: (() -> Void)? = nil
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
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?()
            }
        }
    }
}

private struct TVHomeSecondaryBookmarkButtonLabel: View {
    let isBookmarked: Bool
    var onFocus: (() -> Void)? = nil
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
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?()
            }
        }
    }
}
