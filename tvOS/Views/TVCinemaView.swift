import SwiftUI

public struct TVCinemaView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedItem: MediaItem?
    @State private var hoveredItem: MediaItem? = nil
    @State private var activeRowIndex: Int = 0
    
    public init() {}
    
    private var activeBackgroundItem: MediaItem? {
        hoveredItem ?? engine.cinemaNow.first ?? engine.cinemaUpcoming.first
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background (100% Viewport, Zero Black Spaces, Always Soft Blurred)
                rootBackground(screenWidth: screenWidth, screenHeight: screenHeight)
                
                // Root Vertical ScrollView
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 36) {
                            // Header Section (Zero Hero Banner)
                            cinemaHeaderSection
                                .id("cinema-header")
                            
                            // Theatrical Rows
                            theatricalRowsSection
                        }
                        .padding(.bottom, 220)
                    }
                    .coordinateSpace(name: "cinemaScroll")
                    .onChange(of: activeRowIndex) { _, newIndex in
                        if newIndex == -1 {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                scrollProxy.scrollTo("cinema-header", anchor: .top)
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
        .onAppear {
            AppNavigation.shared.isTopBarVisible = true
        }
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
                    Color.black.opacity(0.46)
                    
                    // Vignette gradient overlays for edge softness
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
    
    // MARK: - Top Header Section (Zero Hero Banner)
    
    private var cinemaHeaderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("CINEMA")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2.0)
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.40), lineWidth: 1))
                
                Text("EXCLUSIVELY IN THEATRES")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.60))
            }
            .padding(.horizontal, 60)
            .padding(.top, 140)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }
    
    // MARK: - Row Hover & Focus Handling
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.65)) {
            self.hoveredItem = item
        }
        if activeRowIndex != rowIndex {
            withAnimation(.easeInOut(duration: 0.65)) {
                self.activeRowIndex = rowIndex
                AppNavigation.shared.isTopBarVisible = true
            }
        }
    }
    
    // MARK: - Theatrical Rows Section (Strictly Verified Theatrical Exclusives)
    
    @ViewBuilder
    private var theatricalRowsSection: some View {
        let exclusiveNow = engine.cinemaNow.filter { $0.isNowPlayingTheatrical }.deduplicated()
        let exclusiveUpcoming = engine.cinemaUpcoming.filter { $0.isUpcomingTheatrical }.deduplicated()
        
        VStack(alignment: .leading, spacing: 32) {
            // Row 0: Now in Theatres (Theatrical Exclusive)
            if !exclusiveNow.isEmpty {
                TVContentRowView(
                    title: "Now in Theatres (Theatrical Exclusive)",
                    items: exclusiveNow,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 0,
                    onHover: { handleRowHover($0, rowIndex: 0) },
                    onMoveUp: { AppNavigation.shared.focusTopBarTrigger += 1 }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-0")
            }
            
            // Row 1: In Theatres & On Streaming (Verified via JustWatch)
            let cinemaStreamingItems = engine.cinemaAndStreaming.deduplicated()
            if !cinemaStreamingItems.isEmpty {
                TVContentRowView(
                    title: "In Theatres & On Streaming",
                    items: cinemaStreamingItems,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-streaming")
            }
            
            // Row 1: Trending in Theatres
            let trendingTheatrical = Array(exclusiveNow.sorted { $0.rating > $1.rating }.prefix(10))
            if !trendingTheatrical.isEmpty {
                TVContentRowView(
                    title: "Trending in Theatres",
                    items: trendingTheatrical,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 1,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-1")
            }
            
            // Row 2: Coming Soon to Theatres (Strictly Future Dates Only)
            if !exclusiveUpcoming.isEmpty {
                TVContentRowView(
                    title: "Coming Soon to Theatres",
                    items: exclusiveUpcoming,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 2,
                    onHover: { handleRowHover($0, rowIndex: 2) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-2")
            }
            
            // Row 3: Critically Acclaimed in Theatres
            let acclaimedTheatrical = exclusiveNow.filter { $0.rating >= 7.5 }
            if !acclaimedTheatrical.isEmpty {
                TVContentRowView(
                    title: "Critically Acclaimed in Theatres",
                    items: acclaimedTheatrical,
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 3,
                    onHover: { handleRowHover($0, rowIndex: 3) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-3")
            }
            
            // Row 4: Upcoming Premium & IMAX Screenings
            if exclusiveUpcoming.count > 2 {
                TVContentRowView(
                    title: "Upcoming Premium & IMAX Screenings",
                    items: Array(exclusiveUpcoming.suffix(from: min(2, exclusiveUpcoming.count))),
                    showCinemaBadge: true,
                    isRowActive: activeRowIndex == 4,
                    onHover: { handleRowHover($0, rowIndex: 4) }
                ) { item in
                    selectedItem = item
                }
                .id("cinema-row-4")
            }
        }
    }
}
