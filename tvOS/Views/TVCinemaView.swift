import SwiftUI

public struct TVCinemaView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedItem: MediaItem?
    @State private var hoveredItem: MediaItem? = nil
    @State private var activeRowIndex: Int = -1
    private var heroIndex: Int {
        get { engine.cinemaHeroIndex }
        nonmutating set { engine.cinemaHeroIndex = newValue }
    }
    @State private var isUserInteracting: Bool = false
    @State private var heroLogoPath: String? = nil
    
    private let timer = Timer.publish(every: 20.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    // Strict Theatrical Exclusivity: Hero pool contains ONLY movies currently in theatres with ZERO streaming options
    private var heroPool: [MediaItem] {
        let pool = engine.exclusiveCinemaNow.isEmpty ? engine.cinemaNow.filter { engine.isTheatricalExclusive($0) } : engine.exclusiveCinemaNow
        return Array(pool.prefix(6))
    }
    
    private var theatricalHero: MediaItem? {
        guard !heroPool.isEmpty else { return nil }
        return heroPool[heroIndex % heroPool.count]
    }
    
    private var isCarouselOutOfView: Bool {
        activeRowIndex >= 1
    }
    
    private var activeBackgroundItem: MediaItem? {
        hoveredItem ?? theatricalHero
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background (100% Viewport, Zero Black Spaces)
                rootBackground(screenWidth: screenWidth, screenHeight: screenHeight)
                
                // Unified Root Vertical ScrollView (Zero Black Bars)
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 1. Massive Theatrical Premiere Hero Section (~920pt presence)
                            if let hero = theatricalHero {
                                cinemaHeroShowcaseSection(hero: hero, screenWidth: screenWidth, screenHeight: screenHeight)
                                    .id("cinemaHeroSection")
                            } else {
                                Color.clear
                                    .frame(width: screenWidth, height: screenHeight)
                                    .id("cinemaHeroSection")
                            }
                            
                            // 2. Strict Theatrical Content Rows with first row peeking (padding top -180)
                            theatricalContentRowsSection
                                .padding(.top, -180)
                        }
                        .padding(.bottom, 260)
                    }
                    .coordinateSpace(name: "cinemaScroll")
                    .onChange(of: activeRowIndex) { _, newIndex in
                        if newIndex == 0 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("cinema-row-0", anchor: UnitPoint(x: 0.5, y: 0.65))
                            }
                        } else if newIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("cinema-row-\(newIndex)", anchor: UnitPoint(x: 0.5, y: 0.48))
                            }
                        } else if newIndex == -1 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("cinemaHeroSection", anchor: .top)
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
        .task(id: theatricalHero?.id) {
            if let hero = theatricalHero {
                heroLogoPath = hero.logoPath
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
                    
                    // Dark scrim for row contrast when scrolled down
                    Color.black.opacity(isCarouselOutOfView ? 0.42 : 0.0)
                    
                    // Subtle vignettes active when carousel hero is in view
                    Group {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.80), location: 0.0),
                                .init(color: Color.black.opacity(0.35), location: 0.35),
                                .init(color: Color.clear, location: 0.65)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.70), location: 0.0),
                                .init(color: Color.clear, location: 0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
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
    
    // MARK: - Massive Theatrical Hero Showcase Section (~920pt presence)
    
    private func cinemaHeroShowcaseSection(hero: MediaItem, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: screenWidth, height: screenHeight)
            
            // Hero Content: Logo/Title, Metadata, Synopsis, Controls & Centered Pagination Dots
            VStack(alignment: .leading, spacing: 14) {
                // Official Transparent Title Logo or Typography Fallback
                Group {
                    if let logoPath = heroLogoPath ?? hero.logoPath,
                       let logoURL = URL(string: "https://image.tmdb.org/t/p/w500\(logoPath)") {
                        CachedAsyncImage(
                            url: logoURL,
                            contentMode: .fit
                        )
                        .frame(maxWidth: 460, maxHeight: 110, alignment: .leading)
                        .shadow(color: Color.black.opacity(0.70), radius: 10, x: 0, y: 5)
                    } else {
                        Text(hero.title.uppercased())
                            .font(.system(size: 50, weight: .black, design: .serif))
                            .tracking(3.0)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: Color.black.opacity(0.85), radius: 8, x: 0, y: 4)
                    }
                }
                .frame(height: 110, alignment: .bottomLeading)
                
                // Metadata Row: Certification, Year, Rating Badge, Runtime, Genres
                HStack(spacing: 14) {
                    if let cert = hero.certification, !cert.isEmpty {
                        Text(cert)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            )
                    }
                    
                    if !hero.yearString.isEmpty {
                        Text(hero.yearString)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if !hero.formattedRating.isEmpty {
                        RatingBadge(rating: hero.formattedRating)
                    }
                    
                    if !hero.formattedTheatricalReleaseDate.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text("In Cinemas: \(hero.formattedTheatricalReleaseDate)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    
                    if !hero.formattedRuntime.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(hero.formattedRuntime)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    if !hero.genreNames.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(hero.genreNames.prefix(3).joined(separator: ", "))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                
                // 2-Line Overview Synopsis
                if !hero.overview.isEmpty {
                    Text(hero.overview)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(2)
                        .lineSpacing(4)
                        .frame(maxWidth: 720, alignment: .leading)
                        .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
                }
                
                // Primary Action Button & Add to Watchlist (Full Width Focus Section)
                HStack {
                    HStack(spacing: 14) {
                        Button {
                            selectedItem = hero
                        } label: {
                            TVCinemaPrimaryHeroButtonLabel(title: "Cinema Details") {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    self.hoveredItem = nil
                                    self.activeRowIndex = -1
                                    self.isUserInteracting = true
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        .onMoveCommand { direction in
                            if direction == .left {
                                withAnimation(.easeInOut(duration: 0.40)) {
                                    heroIndex = (heroIndex - 1 + heroPool.count) % max(1, heroPool.count)
                                }
                            }
                        }
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            TVCinemaSecondaryBookmarkButtonLabel(isBookmarked: watchlist.contains(id: hero.id)) {
                                withAnimation(.easeInOut(duration: 0.45)) {
                                    self.hoveredItem = nil
                                    self.activeRowIndex = -1
                                    self.isUserInteracting = true
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
                            }
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
                .padding(.top, 4)
                
                // Centered Carousel Pagination Dots
                HStack(spacing: 8) {
                    ForEach(0..<min(heroPool.count, 6), id: \.self) { idx in
                        Capsule()
                            .fill(heroIndex % min(heroPool.count, 6) == idx ? Color.white : Color.white.opacity(0.35))
                            .frame(width: heroIndex % min(heroPool.count, 6) == idx ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: heroIndex)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
    
    // MARK: - Strict Theatrical Content Rows
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.50)) {
            self.hoveredItem = item
        }
        if activeRowIndex != rowIndex {
            withAnimation(.easeInOut(duration: 0.50)) {
                self.activeRowIndex = rowIndex
            }
            withAnimation(.easeInOut(duration: 0.35)) {
                AppNavigation.shared.isTopBarVisible = (rowIndex <= 0)
            }
        }
    }
    
    @ViewBuilder
    private var theatricalContentRowsSection: some View {
        let exclusiveNow = engine.exclusiveCinemaNow.isEmpty ? engine.cinemaNow.filter { engine.isTheatricalExclusive($0) } : engine.exclusiveCinemaNow
        let exclusiveUpcoming = engine.exclusiveCinemaUpcoming.isEmpty ? engine.cinemaUpcoming.filter { engine.isTheatricalExclusive($0) } : engine.exclusiveCinemaUpcoming
        
        VStack(alignment: .leading, spacing: 32) {
            // Row 0: Now in Theatres (Theatrical Exclusive) - Peeks in at bottom edge
            if !exclusiveNow.isEmpty {
                TVContentRowView(
                    title: "Now in Theatres (Theatrical Exclusive)",
                    items: exclusiveNow,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 0,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-0")
            }
            
            // Row 1: Coming Soon to Theatres (Near Future - All Posters Portrait with Hover Extend)
            if !exclusiveUpcoming.isEmpty {
                TVContentRowView(
                    title: "Coming Soon to Theatres (Near Future)",
                    items: exclusiveUpcoming,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-1")
            }
            
            // Row 2: Top Box Office Hits (In Theatres Only)
            let boxOfficeHits = exclusiveNow.filter { $0.rating >= 7.0 }
            if !boxOfficeHits.isEmpty {
                TVContentRowView(
                    title: "Top Box Office Hits (In Theatres Only)",
                    items: boxOfficeHits,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-2")
            }
            
            // Row 3: Upcoming Premium & IMAX Screenings
            if exclusiveUpcoming.count > 2 {
                TVContentRowView(
                    title: "Upcoming Premium & IMAX Screenings",
                    items: Array(exclusiveUpcoming.suffix(from: min(2, exclusiveUpcoming.count))),
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-3")
            }
        }
    }
}

// MARK: - Dedicated Focusable Cinema Hero Button Labels

private struct TVCinemaPrimaryHeroButtonLabel: View {
    let title: String
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket.fill")
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

private struct TVCinemaSecondaryBookmarkButtonLabel: View {
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
