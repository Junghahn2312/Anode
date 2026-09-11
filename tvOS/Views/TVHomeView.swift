import SwiftUI
import Combine

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var trakt = TraktStore.shared
    
    private var heroIndex: Int {
        get { engine.homeHeroIndex }
        nonmutating set { engine.homeHeroIndex = newValue }
    }
    @State private var isUserInteracting: Bool = false
    @State private var selectedItem: MediaItem?
    @State private var heroAvailability: WatchAvailability?
    @State private var heroLogoPath: String? = nil
    @State private var hoveredItem: MediaItem? = nil
    @State private var activeRowIndex: Int = -1
    @FocusState private var isHeroFocused: Bool
    
    private let timer = Timer.publish(every: 20.0, on: .main, in: .common).autoconnect()
    
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
        if activeRowIndex == 0 {
            // Continue Watching row does NOT affect the background at all
            return spotlightHero
        }
        return hoveredItem ?? spotlightHero
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
                            // 1. Full-Screen Hero Spotlight Section (~920pt presence, Zero Black Bars)
                            if let hero = spotlightHero {
                                heroShowcaseSection(hero: hero, screenWidth: screenWidth, screenHeight: screenHeight)
                                    .id("heroSection")
                            } else {
                                Color.clear
                                    .frame(width: screenWidth, height: screenHeight)
                                    .id("heroSection")
                            }
                            
                            // 2. Content Rows with Continue Watching peeking at bottom (padding top -180)
                            contentRowsSection
                                .padding(.top, -180)
                        }
                        .padding(.bottom, 260)
                    }
                    .coordinateSpace(name: "homeScroll")
                    .onChange(of: activeRowIndex) { _, newIndex in
                        if newIndex == 0 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("row-0", anchor: UnitPoint(x: 0.5, y: 0.65))
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
            if activeRowIndex == -1 && !isUserInteracting && !heroPool.isEmpty {
                withAnimation(.easeInOut(duration: 0.8)) {
                    heroIndex = (heroIndex + 1) % heroPool.count
                }
            }
        }
        .task(id: spotlightHero?.id) {
            if let hero = spotlightHero {
                heroLogoPath = hero.logoPath
                heroAvailability = await engine.fetchAvailability(for: hero)
                if heroLogoPath == nil {
                    if let logo = await engine.fetchLogo(for: hero) {
                        heroLogoPath = logo
                    }
                }
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
                    .id(bgItem.id)
                    .transition(.opacity)
                    
                    // Hardware-accelerated frosted glass overlay when carousel is out of view
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(isCarouselOutOfView ? 0.90 : 0.0)
                    
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
    
    // MARK: - Massive Hero Showcase Section (Matching Photo 1)
    
    private func heroShowcaseSection(hero: MediaItem, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: screenWidth, height: screenHeight)
            
            // Hero Typography, Metadata, Action Controls & Centered Pagination Dots
            VStack(alignment: .leading, spacing: 14) {
                // Hero Title: Transparent Logo Image (ClearArt) with Serif Fallback (Matching Photo 1)
                Group {
                    if let logoPath = heroLogoPath ?? hero.logoPath,
                       let logoURL = URL(string: logoPath.hasPrefix("http") ? logoPath : "https://image.tmdb.org/t/p/w500\(logoPath)") {
                        CachedAsyncImage(url: logoURL, contentMode: .fit)
                            .frame(maxHeight: 110, alignment: .leading)
                            .shadow(color: Color.black.opacity(0.85), radius: 8, x: 0, y: 3)
                    } else {
                        Text(hero.title.uppercased())
                            .font(.system(size: 48, weight: .heavy, design: .serif))
                            .foregroundColor(Color(red: 0.96, green: 0.72, blue: 0.28))
                            .shadow(color: Color.black.opacity(0.90), radius: 6, x: 0, y: 3)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                
                // Metadata Line: Year • Genre • Certification • Rating (Matching Photo 1)
                HStack(spacing: 12) {
                    if !hero.yearString.isEmpty {
                        Text(hero.yearString)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if let genre = hero.genreNames.first {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(genre)
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
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    
                    if !hero.formattedRating.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        RatingBadge(rating: hero.formattedRating)
                    }
                }
                
                // Synopsis (2 lines with ellipsis, matching Photo 1)
                if !hero.overview.isEmpty {
                    Text(hero.overview)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .lineSpacing(4)
                        .frame(maxWidth: 840, alignment: .leading)
                        .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
                }
                
                // Action Controls: Full-width container with Left/Right carousel navigation & Focus section
                HStack {
                    HStack(spacing: 16) {
                        Button {
                            selectedItem = hero
                        } label: {
                            TVHomePrimaryHeroButtonLabel(
                                title: hero.mediaType == .tvShow ? "Go to Series" : "Go to Movie"
                            ) {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    self.hoveredItem = nil
                                    self.activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        .focused($isHeroFocused)
                        .onMoveCommand { direction in
                            if direction == .left {
                                withAnimation(.easeInOut(duration: 0.40)) {
                                    heroIndex = (heroIndex - 1 + heroPool.count) % max(1, heroPool.count)
                                }
                            } else if direction == .up {
                                AppNavigation.shared.focusTopBarTrigger += 1
                            }
                        }
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            TVHomeSecondaryBookmarkButtonLabel(
                                isBookmarked: watchlist.contains(id: hero.id)
                            ) {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    self.hoveredItem = nil
                                    self.activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        .onMoveCommand { direction in
                            if direction == .right {
                                withAnimation(.easeInOut(duration: 0.40)) {
                                    heroIndex = (heroIndex + 1) % max(1, heroPool.count)
                                }
                            } else if direction == .up {
                                AppNavigation.shared.focusTopBarTrigger += 1
                            }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
                .padding(.top, 4)
                .onChange(of: isHeroFocused) { _, focused in
                    if focused {
                        withAnimation(.easeInOut(duration: 0.40)) {
                            self.hoveredItem = nil
                            self.activeRowIndex = -1
                            AppNavigation.shared.isTopBarVisible = true
                        }
                    }
                }
                
                // Centered Carousel Page Indicator Dots (Matching Photo 1)
                HStack {
                    Spacer()
                    let totalDots = min(heroPool.count, 8)
                    let currentIndex = heroIndex % max(1, heroPool.count)
                    HStack(spacing: 8) {
                        ForEach(0..<totalDots, id: \.self) { idx in
                            let isActive = (currentIndex % totalDots) == idx
                            Circle()
                                .fill(isActive ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 7, height: 7)
                                .animation(.spring(response: 0.40, dampingFraction: 0.85), value: isActive)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 6)
            }
            .id(hero.id)
            .transition(.opacity)
            .padding(.horizontal, 60)
            .padding(.bottom, 210)
        }
        .frame(width: screenWidth, height: screenHeight)
        .animation(.easeInOut(duration: 0.45), value: hero.id)
    }
    
    // MARK: - Content Rows Section with Continue Watching & Subtle Ranked Numerals
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        if rowIndex == 0 {
            // Continue Watching row does NOT affect the background at all
            withAnimation(.easeInOut(duration: 0.45)) {
                self.hoveredItem = nil
            }
        } else {
            withAnimation(.easeInOut(duration: 0.45)) {
                self.hoveredItem = item
            }
        }
        if activeRowIndex != rowIndex {
            withAnimation(.easeInOut(duration: 0.50)) {
                self.activeRowIndex = rowIndex
                AppNavigation.shared.isTopBarVisible = (rowIndex <= 0)
            }
        }
    }
    
    // MARK: - Cross-Row Media Deduplication Engine (Zero Repeated Titles)
    
    private struct HomeRowCollections {
        let trendingFilms: [MediaItem]
        let trendingSeries: [MediaItem]
        let topTen: [MediaItem]
        let popular: [MediaItem]
        let cinema: [MediaItem]
        let netflix: [MediaItem]
        let disney: [MediaItem]
        let prime: [MediaItem]
        let apple: [MediaItem]
        let upcoming: [MediaItem]
        let topRated: [MediaItem]
    }
    
    private func deduplicated(items: [MediaItem], seen: inout Set<Int>, limit: Int = 10) -> [MediaItem] {
        var result: [MediaItem] = []
        for item in items {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                result.append(item)
                if result.count >= limit {
                    break
                }
            }
        }
        return result
    }
    
    private var rowCollections: HomeRowCollections {
        var seen = Set<Int>()
        
        // 1. Exclude Trakt Continue Watching items
        for cw in trakt.items {
            seen.insert(cw.item.id)
        }
        
        // 2. Preserve Top 10 Today official ranks (Priority seeding)
        let topTen = Array(engine.topTen.prefix(10))
        for item in topTen {
            seen.insert(item.id)
        }
        
        // 3. Deduplicate every subsequent row so zero titles repeat anywhere on Home
        let trendingFilms = deduplicated(items: engine.popularMovies + engine.cinemaNow, seen: &seen, limit: 10)
        let trendingSeries = deduplicated(items: engine.popularTV + engine.trendingItems.filter { $0.mediaType == .tvShow }, seen: &seen, limit: 10)
        let popular = deduplicated(items: engine.popularMovies + engine.popularTV, seen: &seen, limit: 10)
        let cinema = deduplicated(items: engine.cinemaNow, seen: &seen, limit: 10)
        let netflix = deduplicated(items: engine.netflixTrending, seen: &seen, limit: 10)
        let disney = deduplicated(items: engine.disneyTrending, seen: &seen, limit: 10)
        let prime = deduplicated(items: engine.primeTrending, seen: &seen, limit: 10)
        let apple = deduplicated(items: engine.appleTVTrending, seen: &seen, limit: 10)
        let upcoming = deduplicated(items: engine.cinemaUpcoming, seen: &seen, limit: 10)
        let topRated = deduplicated(items: engine.topRated, seen: &seen, limit: 10)
        
        return HomeRowCollections(
            trendingFilms: trendingFilms,
            trendingSeries: trendingSeries,
            topTen: topTen,
            popular: popular,
            cinema: cinema,
            netflix: netflix,
            disney: disney,
            prime: prime,
            apple: apple,
            upcoming: upcoming,
            topRated: topRated
        )
    }
    
    @ViewBuilder
    private var contentRowsSection: some View {
        let rows = rowCollections
        
        VStack(alignment: .leading, spacing: 32) {
            // Row 0: Continue Watching (Peeks in at bottom edge when at top of page, Photo 1)
            if !trakt.items.isEmpty {
                TVContinueWatchingRowView(
                    items: trakt.items,
                    onHover: { handleRowHover($0, rowIndex: 0) },
                    onMoveUp: { isHeroFocused = true }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-0")
            }
            
            // Row 1: Trending Films (Subtle numerals in top-left corner of poster, Photo 2)
            if !rows.trendingFilms.isEmpty {
                TVTopTenRowView(
                    title: "Trending Films",
                    items: rows.trendingFilms,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) },
                    onMoveUp: { isHeroFocused = true }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-1")
            }
            
            // Row 2: Trending Series (Subtle numerals in top-left corner of poster, Photo 2)
            if !rows.trendingSeries.isEmpty {
                TVTopTenRowView(
                    title: "Trending Series",
                    items: rows.trendingSeries,
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-2")
            }
            
            // Row 3: Top 10 Today
            if !rows.topTen.isEmpty {
                TVTopTenRowView(
                    title: "Top 10 Today",
                    items: rows.topTen,
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-3")
            }
            
            // Row 4: Popular (All posters portrait with hover extend)
            if !rows.popular.isEmpty {
                TVContentRowView(
                    title: "Popular",
                    items: rows.popular,
                    isRowActive: activeRowIndex == 4,
                    onHover: { handleRowHover($0, rowIndex: 4) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-4")
            }
            
            // Row 5: My Watchlist (if populated)
            if !watchlist.items.isEmpty {
                TVContentRowView(
                    title: "My List",
                    items: watchlist.items,
                    isRowActive: activeRowIndex == 5,
                    onHover: { handleRowHover($0, rowIndex: 5) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-5")
            }
            
            // Row 6: Now in Cinemas
            if !rows.cinema.isEmpty {
                TVContentRowView(
                    title: "Now in Cinemas",
                    items: rows.cinema,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 6,
                    onHover: { handleRowHover($0, rowIndex: 6) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-6")
            }
            
            // Row 7: Trending on Netflix
            if !rows.netflix.isEmpty {
                TVContentRowView(
                    title: "Trending on Netflix",
                    items: rows.netflix,
                    isRowActive: activeRowIndex == 7,
                    onHover: { handleRowHover($0, rowIndex: 7) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-7")
            }
            
            // Row 8: Trending on Disney+
            if !rows.disney.isEmpty {
                TVContentRowView(
                    title: "Trending on Disney+",
                    items: rows.disney,
                    isRowActive: activeRowIndex == 8,
                    onHover: { handleRowHover($0, rowIndex: 8) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-8")
            }
            
            // Row 9: Trending on Prime Video
            if !rows.prime.isEmpty {
                TVContentRowView(
                    title: "Trending on Prime Video",
                    items: rows.prime,
                    isRowActive: activeRowIndex == 9,
                    onHover: { handleRowHover($0, rowIndex: 9) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-9")
            }
            
            // Row 10: Trending on Apple TV+
            if !rows.apple.isEmpty {
                TVContentRowView(
                    title: "Trending on Apple TV+",
                    items: rows.apple,
                    isRowActive: activeRowIndex == 10,
                    onHover: { handleRowHover($0, rowIndex: 10) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-10")
            }
            
            // Row 11: Coming Soon to Theatres (Portrait Posters with Hover Extend)
            if !rows.upcoming.isEmpty {
                TVContentRowView(
                    title: "Coming Soon to Theatres",
                    items: rows.upcoming,
                    isRowActive: activeRowIndex == 11,
                    onHover: { handleRowHover($0, rowIndex: 11) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-11")
            }
            
            // Row 12: Critically Acclaimed
            if !rows.topRated.isEmpty {
                TVContentRowView(
                    title: "Critically Acclaimed",
                    items: rows.topRated,
                    isRowActive: activeRowIndex == 12,
                    onHover: { handleRowHover($0, rowIndex: 12) }
                ) { item in
                    isUserInteracting = true
                    selectedItem = item
                }
                .id("row-12")
            }
        }
    }
}

// MARK: - Dedicated Focusable Hero Button Label Helpers

private struct TVHomePrimaryHeroButtonLabel: View {
    let title: String
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
            Text(title)
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.25), lineWidth: isFocused ? 2.5 : 1)
        )
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.4) : Color.clear, radius: 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocusAction()
            }
        }
    }
}

private struct TVHomeSecondaryBookmarkButtonLabel: View {
    let isBookmarked: Bool
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16, weight: .bold))
            Text(isBookmarked ? "In My List" : "Add to List")
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.25), lineWidth: isFocused ? 2.5 : 1)
        )
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.4) : Color.clear, radius: 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocusAction()
            }
        }
    }
}
