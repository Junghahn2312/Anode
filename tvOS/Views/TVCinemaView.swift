import SwiftUI

public struct TVCinemaView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedItem: MediaItem?
    @State private var hoveredItem: MediaItem? = nil
    
    public init() {}
    
    private var theatricalHero: MediaItem? {
        engine.cinemaNow.first ?? engine.cinemaMovies.first ?? engine.trendingItems.first
    }
    
    private var activeBackgroundItem: MediaItem? {
        hoveredItem ?? theatricalHero
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background (100% Viewport, Zero Black Spaces)
                rootBackground(screenGeo: screenGeo)
                
                // Unified Root Vertical ScrollView (Zero Black Bars)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Full-Screen Theatrical Premiere Hero Section
                        if let hero = theatricalHero {
                            cinemaHeroSection(hero: hero, screenGeo: screenGeo)
                        } else {
                            Color.clear
                                .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        }
                        
                        // 2. Theatrical Content Rows with Dynamic Expanding Cards (Image 2)
                        VStack(alignment: .leading, spacing: 32) {
                            // Now in Cinemas Row
                            if !engine.cinemaNow.isEmpty {
                                TVContentRowView(
                                    title: "Now in Cinemas",
                                    items: engine.cinemaNow,
                                    showCinemaBadge: true,
                                    onHover: handleRowHover
                                ) { item in
                                    selectedItem = item
                                }
                            }
                            
                            // Coming Soon to Cinemas Row (Landscape 16:9)
                            if !engine.cinemaUpcoming.isEmpty {
                                TVLandscapeRowView(
                                    title: "Coming Soon to Cinemas",
                                    items: engine.cinemaUpcoming,
                                    onHover: handleRowHover
                                ) { item in
                                    selectedItem = item
                                }
                            }
                            
                            // Critically Acclaimed Theatrical Releases
                            if !engine.cinemaMovies.isEmpty {
                                TVContentRowView(
                                    title: "Critically Acclaimed in Theatres",
                                    items: engine.cinemaMovies.filter { $0.rating >= 7.5 },
                                    onHover: handleRowHover
                                ) { item in
                                    selectedItem = item
                                }
                            }
                        }
                        .offset(y: -260)
                        .padding(.bottom, 120)
                    }
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Dynamic Full-Screen Background (Zero Black Spaces)
    
    private func rootBackground(screenGeo: GeometryProxy) -> some View {
        ZStack {
            // Dark base color to guarantee zero harsh flashes
            Color(red: 0.04, green: 0.04, blue: 0.05)
                .ignoresSafeArea()
            
            if let bgItem = activeBackgroundItem {
                let backdropURL = bgItem.backdropURL(size: "w1280") ?? bgItem.posterURL(size: "original")
                ZStack {
                    if hoveredItem != nil {
                        // When hovering over an item in any list/row:
                        CachedAsyncImage(
                            url: backdropURL,
                            contentMode: .fill
                        )
                        .frame(width: screenGeo.size.width + 40, height: screenGeo.size.height + 40)
                        .clipped()
                        .blur(radius: 35)
                        
                        Color.black.opacity(0.42)
                    } else {
                        // 1. Sharp backdrop artwork
                        CachedAsyncImage(
                            url: backdropURL,
                            contentMode: .fill
                        )
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        .clipped()
                        
                        // 2. Blurred lower region behind lists
                        CachedAsyncImage(
                            url: backdropURL,
                            contentMode: .fill
                        )
                        .frame(width: screenGeo.size.width + 40, height: screenGeo.size.height + 40)
                        .clipped()
                        .blur(radius: 35)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .clear, location: 0.45),
                                    .init(color: .black, location: 0.68),
                                    .init(color: .black, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
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
                        
                        // Translucent tint behind lists to ensure full legibility with zero black voids
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.40),
                                .init(color: Color.black.opacity(0.35), location: 0.70),
                                .init(color: Color.black.opacity(0.50), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .id(bgItem.id)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.55), value: bgItem.id)
            }
        }
        .ignoresSafeArea()
    }
    
    private func handleRowHover(_ item: MediaItem) {
        withAnimation(.easeInOut(duration: 0.55)) {
            self.hoveredItem = item
        }
    }
    
    // MARK: - Cinema Hero Showcase Section (~820pt, peeking first row below)
    
    private func cinemaHeroSection(hero: MediaItem, screenGeo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .frame(width: screenGeo.size.width, height: screenGeo.size.height)
            
            // Hero Content
            VStack(alignment: .leading, spacing: 14) {
                // Theatrical Header Pill
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                        
                        Text("NOW IN THEATRES")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.18))
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
                    
                    Text("GLOBAL BOX OFFICE")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, 140)
                
                // Hero Information
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text("THEATRICAL RELEASE")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.85))
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                    )
                            )
                        
                        if !hero.formattedRating.isEmpty {
                            RatingBadge(rating: hero.formattedRating)
                        }
                        
                        if !hero.yearString.isEmpty {
                            Text(hero.yearString)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let genre = hero.genreNames.first {
                            Text("•")
                                .foregroundColor(.white.opacity(0.4))
                            Text(genre)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Text(hero.title)
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.85), radius: 6, x: 0, y: 3)
                    
                    if !hero.overview.isEmpty {
                        Text(hero.overview)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .lineSpacing(3)
                            .frame(maxWidth: 780, alignment: .leading)
                    }
                    
                    HStack(spacing: 14) {
                        Button {
                            selectedItem = hero
                        } label: {
                            CinemaHeroPrimaryButtonLabel {
                                withAnimation(.easeInOut(duration: 0.55)) {
                                    self.hoveredItem = nil
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            CinemaHeroBookmarkButtonLabel(isBookmarked: watchlist.contains(id: hero.id)) {
                                withAnimation(.easeInOut(duration: 0.55)) {
                                    self.hoveredItem = nil
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                    .focusSection()
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 280)
        }
        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
        .animation(.easeInOut(duration: 0.45), value: hero.id)
    }
}

// MARK: - Focusable Buttons

private struct CinemaHeroPrimaryButtonLabel: View {
    var onFocus: (() -> Void)? = nil
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 16, weight: .black))
            Text("Cinema Details")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.22))
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

private struct CinemaHeroBookmarkButtonLabel: View {
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
                .fill(isFocused ? Color(white: 0.35) : Color.white.opacity(0.14))
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
