import SwiftUI

public struct TVDiscoveryView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedProvider: StreamingProvider? = nil
    @State private var selectedMediaType: MediaTypeFilter = .all
    @State private var selectedGenre: GenreCategory? = nil
    
    @State private var platformTopMovies: [MediaItem] = []
    @State private var platformTopTV: [MediaItem] = []
    @State private var platformNew: [MediaItem] = []
    @State private var isLoadingPlatform: Bool = false
    
    @State private var selectedItem: MediaItem? = nil
    @State private var hoveredItem: MediaItem? = nil
    @State private var activeRowIndex: Int = -1
    
    public enum MediaTypeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    private var activeBackgroundItem: MediaItem? {
        hoveredItem ?? engine.trendingItems.first ?? engine.freshFromTheatres.first
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
                        VStack(alignment: .leading, spacing: 32) {
                            // 1. Top Section: Discovery Badge & Small Streaming Platform Tab Buttons (Zero Hero)
                            topStreamingPlatformsSection
                                .id("discovery-top")
                            
                            // 2. Main Content: Either Selected Platform View or Filtered All-Catalog View
                            if let provider = selectedProvider {
                                platformCatalogSection(provider: provider)
                                    .id("discovery-platform-catalog")
                            } else {
                                allMediaCatalogSection
                                    .id("discovery-all-catalog")
                            }
                        }
                        .padding(.bottom, 160)
                    }
                    .coordinateSpace(name: "discoveryScroll")
                    .onChange(of: activeRowIndex) { _, newIndex in
                        if newIndex >= 0 {
                            withAnimation(.easeInOut(duration: 0.50)) {
                                scrollProxy.scrollTo("discovery-row-\(newIndex)", anchor: UnitPoint(x: 0.5, y: 0.48))
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
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Dynamic Full-Screen Background (Zero Black Spaces, Always Soft Blurred)
    
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
                    .blur(radius: 40)
                    .id(bgItem.id)
                    .transition(.opacity)
                    
                    // Dark scrim overlay for high contrast readability
                    Color.black.opacity(0.48)
                    
                    // Subtle vignettes for edge softness
                    Group {
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.75), location: 0.0),
                                .init(color: Color.clear, location: 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.65),
                                .init(color: Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.85), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.55), value: bgItem.id)
            }
        }
        .frame(width: screenWidth, height: screenHeight)
        .ignoresSafeArea()
    }
    
    // MARK: - Top Streaming Platform Selector Tab Buttons (Zero Hero)
    
    private var topStreamingPlatformsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Badges
            HStack(spacing: 12) {
                Text("DISCOVERY")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.0)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                
                Text("STREAMING PLATFORMS & MEDIA CATALOG")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 60)
            .padding(.top, 140)
            
            // Small Platform Tab Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // All Media Catalog Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            selectedProvider = nil
                            hoveredItem = nil
                            activeRowIndex = -1
                            AppNavigation.shared.isTopBarVisible = true
                        }
                    } label: {
                        DiscoveryPlatformPillLabel(
                            title: "All Catalog",
                            brandColor: .cyan,
                            isSelected: selectedProvider == nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                selectedProvider = nil
                                hoveredItem = nil
                                activeRowIndex = -1
                                AppNavigation.shared.isTopBarVisible = true
                            }
                        }
                    }
                    .buttonStyle(.tvCard)
                    
                    // Streaming Platform Buttons
                    ForEach(StreamingProvider.allCases, id: \.id) { provider in
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                selectedProvider = provider
                                hoveredItem = nil
                                activeRowIndex = -1
                                AppNavigation.shared.isTopBarVisible = true
                            }
                            Task { await loadPlatformContent(provider) }
                        } label: {
                            DiscoveryPlatformPillLabel(
                                title: provider.name,
                                brandColor: provider.brandColor,
                                isSelected: selectedProvider?.id == provider.id
                            ) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    selectedProvider = provider
                                    hoveredItem = nil
                                    activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                                Task { await loadPlatformContent(provider) }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 6)
            }
        }
    }
    
    // MARK: - Dedicated Streaming Platform Catalog Section
    
    @ViewBuilder
    private func platformCatalogSection(provider: StreamingProvider) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            // Platform Brand Header
            HStack(spacing: 12) {
                Circle()
                    .fill(provider.brandColor)
                    .frame(width: 10, height: 10)
                
                Text("STREAMING ON \(provider.name.uppercased())")
                    .font(.system(size: 13, weight: .black))
                    .tracking(2.0)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedProvider = nil
                        hoveredItem = nil
                        activeRowIndex = -1
                        AppNavigation.shared.isTopBarVisible = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .bold))
                        Text("Back to All Catalog")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.tvCard)
            }
            .padding(.horizontal, 60)
            
            if isLoadingPlatform {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 28) {
                        ForEach(0..<6, id: \.self) { _ in
                            TVSkeletonCardView(width: 210)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
                }
            } else {
                // Row 0: Top 10 Movies Trending on [Platform]
                if !platformTopMovies.isEmpty {
                    TVTopTenRowView(
                        title: "Top 10 Movies Trending on \(provider.name)",
                        items: Array(platformTopMovies.prefix(10)),
                        isRowActive: activeRowIndex == 0,
                        onHover: { handleRowHover($0, rowIndex: 0) }
                    ) { item in
                        selectedItem = item
                    }
                    .id("discovery-row-0")
                }
                
                // Row 1: Top 10 TV Shows Trending on [Platform]
                if !platformTopTV.isEmpty {
                    TVTopTenRowView(
                        title: "Top 10 TV Shows Trending on \(provider.name)",
                        items: Array(platformTopTV.prefix(10)),
                        isRowActive: activeRowIndex == 1,
                        onHover: { handleRowHover($0, rowIndex: 1) }
                    ) { item in
                        selectedItem = item
                    }
                    .id("discovery-row-1")
                }
                
                // Row 2: New to [Platform]
                if !platformNew.isEmpty {
                    TVContentRowView(
                        title: "New to \(provider.name)",
                        items: platformNew,
                        isRowActive: activeRowIndex == 2,
                        onHover: { handleRowHover($0, rowIndex: 2) }
                    ) { item in
                        selectedItem = item
                    }
                    .id("discovery-row-2")
                }
                
                // Row 3: Critically Acclaimed on [Platform]
                let acclaimed = (platformTopMovies + platformTopTV).filter { $0.rating >= 7.5 }
                if !acclaimed.isEmpty {
                    TVContentRowView(
                        title: "Critically Acclaimed on \(provider.name)",
                        items: acclaimed,
                        isRowActive: activeRowIndex == 3,
                        onHover: { handleRowHover($0, rowIndex: 3) }
                    ) { item in
                        selectedItem = item
                    }
                    .id("discovery-row-3")
                }
            }
        }
    }
    
    // MARK: - Main All-Catalog Section with Filters & Genres ("All Movies Ever with Filters")
    
    @ViewBuilder
    private var allMediaCatalogSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Media Type Filters & Curated Genres Row
            VStack(alignment: .leading, spacing: 14) {
                // Media Type Filters
                HStack(spacing: 12) {
                    ForEach(MediaTypeFilter.allCases) { filter in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedMediaType = filter
                                hoveredItem = nil
                                activeRowIndex = -1
                                AppNavigation.shared.isTopBarVisible = true
                            }
                        } label: {
                            DiscoveryFilterPillLabel(
                                title: filter.rawValue,
                                isSelected: selectedMediaType == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    selectedMediaType = filter
                                    hoveredItem = nil
                                    activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                
                // Curated Genre Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "All Genres" pill
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedGenre = nil
                                hoveredItem = nil
                                activeRowIndex = -1
                                AppNavigation.shared.isTopBarVisible = true
                            }
                        } label: {
                            DiscoveryFilterPillLabel(
                                title: "All Genres",
                                isSelected: selectedGenre == nil
                            ) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    selectedGenre = nil
                                    hoveredItem = nil
                                    activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        
                        ForEach(GenreCategory.allCurated) { genre in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedGenre = genre
                                    hoveredItem = nil
                                    activeRowIndex = -1
                                    AppNavigation.shared.isTopBarVisible = true
                                }
                            } label: {
                                DiscoveryFilterPillLabel(
                                    title: genre.name,
                                    isSelected: selectedGenre?.id == genre.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        selectedGenre = genre
                                        hoveredItem = nil
                                        activeRowIndex = -1
                                        AppNavigation.shared.isTopBarVisible = true
                                    }
                                }
                            }
                            .buttonStyle(.tvCard)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 4)
                }
            }
            
            // Dedicated Section: Fresh from Theatres (New to Rent or Buy)
            if selectedMediaType != .tvShows && !engine.freshFromTheatres.isEmpty {
                TVContentRowView(
                    title: "Fresh from Theatres (New to Rent or Buy)",
                    items: engine.freshFromTheatres,
                    isRowActive: activeRowIndex == 0,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-0")
            }
            
            // Filtered Content Rows
            filteredCatalogRows
        }
    }
    
    // MARK: - Dynamic Filtered Catalog Content Rows
    
    @ViewBuilder
    private var filteredCatalogRows: some View {
        if let genre = selectedGenre {
            // Genre-Specific Rows
            let allItems = (engine.popularMovies + engine.popularTV + engine.trendingItems)
            let genreFiltered = allItems.filter { item in
                item.genreNames.contains { g in g.localizedCaseInsensitiveContains(genre.name) }
            }
            let matchingMovies = genreFiltered.filter { $0.mediaType == .movie }
            let matchingTV = genreFiltered.filter { $0.mediaType == .tvShow }
            
            if selectedMediaType != .tvShows && !matchingMovies.isEmpty {
                TVContentRowView(
                    title: "\(genre.name) Movies",
                    items: matchingMovies,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-1")
            }
            
            if selectedMediaType != .movies && !matchingTV.isEmpty {
                TVContentRowView(
                    title: "\(genre.name) Series & Shows",
                    items: matchingTV,
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-2")
            }
            
            let topRatedGenre = genreFiltered.filter { $0.rating >= 8.0 }
            if !topRatedGenre.isEmpty {
                TVContentRowView(
                    title: "Top Rated \(genre.name)",
                    items: topRatedGenre,
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-3")
            }
        } else {
            // General Catalog Rows based on selectedMediaType
            switch selectedMediaType {
            case .all:
                TVContentRowView(
                    title: "Trending Worldwide",
                    items: engine.trendingItems,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-1")
                
                TVContentRowView(
                    title: "Popular Movies",
                    items: engine.popularMovies,
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-2")
                
                TVContentRowView(
                    title: "Popular TV Shows",
                    items: engine.popularTV,
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-3")
                
                TVContentRowView(
                    title: "Critically Acclaimed of All Time",
                    items: engine.topRated,
                    isRowActive: activeRowIndex == 4,
                    onHover: { handleRowHover($0, rowIndex: 4) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-4")
                
            case .movies:
                TVContentRowView(
                    title: "Trending Movies",
                    items: engine.popularMovies,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-1")
                
                TVContentRowView(
                    title: "Top Rated Feature Films",
                    items: engine.topRated.filter { $0.mediaType == .movie },
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-2")
                
                TVContentRowView(
                    title: "New Digital Releases",
                    items: engine.newReleases.filter { $0.mediaType == .movie },
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-3")
                
            case .tvShows:
                TVContentRowView(
                    title: "Trending Television Series",
                    items: engine.popularTV,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-1")
                
                TVContentRowView(
                    title: "Critically Acclaimed Drama Series",
                    items: (engine.popularTV + engine.trendingItems).filter { $0.mediaType == .tvShow && $0.rating >= 8.2 },
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-2")
                
                TVContentRowView(
                    title: "Popular Streaming Series",
                    items: engine.trendingItems.filter { $0.mediaType == .tvShow },
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("discovery-row-3")
            }
        }
    }
    
    // MARK: - Row Hover & Platform Loading Helpers
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.45)) {
            self.hoveredItem = item
        }
        if activeRowIndex != rowIndex {
            self.activeRowIndex = rowIndex
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            AppNavigation.shared.isTopBarVisible = (rowIndex <= 0)
        }
    }
    
    private func loadPlatformContent(_ provider: StreamingProvider) async {
        isLoadingPlatform = true
        async let topMoviesTask = engine.loadPlatformTopMovies(provider: provider)
        async let topTVTask = engine.loadPlatformTopTV(provider: provider)
        async let newTask = engine.loadPlatformNew(provider: provider)
        
        self.platformTopMovies = await topMoviesTask
        self.platformTopTV = await topTVTask
        self.platformNew = await newTask
        isLoadingPlatform = false
    }
}

// MARK: - Dedicated Focusable Platform & Filter Pill Labels

private struct DiscoveryPlatformPillLabel: View {
    let title: String
    let brandColor: Color
    let isSelected: Bool
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.80)
    }
    
    private var backgroundColor: Color {
        if isFocused { return .white }
        return isSelected ? brandColor.opacity(0.35) : Color.white.opacity(0.08)
    }
    
    private var borderColor: Color {
        if isFocused { return .white }
        return isSelected ? brandColor.opacity(0.70) : Color.white.opacity(0.16)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(brandColor)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 8)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocusAction()
            }
        }
    }
}

private struct DiscoveryFilterPillLabel: View {
    let title: String
    let isSelected: Bool
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.80)
    }
    
    private var backgroundColor: Color {
        if isFocused { return .white }
        return isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.08)
    }
    
    private var borderColor: Color {
        if isFocused { return .white }
        return isSelected ? Color.white.opacity(0.50) : Color.white.opacity(0.14)
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? Color.white.opacity(0.3) : Color.clear, radius: 6)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isFocused)
            .onChange(of: isFocused) { _, focused in
                if focused {
                    onFocusAction()
                }
            }
    }
}
