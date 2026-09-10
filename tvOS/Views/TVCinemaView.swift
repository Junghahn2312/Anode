import SwiftUI

public struct TVCinemaView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    @State private var selectedItem: MediaItem?
    @State private var focusedItem: MediaItem?
    
    public init() {}
    
    private var defaultCinemaHero: MediaItem? {
        engine.cinemaNow.first ?? engine.cinemaMovies.first ?? engine.trendingItems.first
    }
    
    private var currentHero: MediaItem? {
        if let focusedItem {
            return focusedItem
        }
        return defaultCinemaHero
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
                                .init(color: Color.black.opacity(0.85), location: 0.38),
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
                
                // Foreground Layout:
                // Top stationary cinema hero showcase (~46% height) + Scrollable rows (~54% height)
                VStack(alignment: .leading, spacing: 0) {
                    cinemaShowcaseSection(screenGeo: screenGeo)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.46, alignment: .bottomLeading)
                    
                    // Scrollable Theatrical Rows
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 36) {
                            // Now in Cinemas Row
                            if !engine.cinemaNow.isEmpty {
                                cinemaRow(
                                    title: "Now in Cinemas",
                                    subtitle: "Experience on the big screen this week",
                                    items: engine.cinemaNow,
                                    isLandscape: false
                                )
                            }
                            
                            // Coming Soon to Cinemas Row (Landscape 16:9)
                            if !engine.cinemaUpcoming.isEmpty {
                                cinemaRow(
                                    title: "Coming Soon to Cinemas",
                                    subtitle: "Upcoming theatrical releases hitting the big screen worldwide",
                                    items: engine.cinemaUpcoming,
                                    isLandscape: true
                                )
                            }
                            
                            // Critically Acclaimed Theatrical Releases
                            if !engine.cinemaMovies.isEmpty {
                                cinemaRow(
                                    title: "Critically Acclaimed in Theatres",
                                    subtitle: "Highest audience and critical reception",
                                    items: engine.cinemaMovies.filter { $0.rating >= 7.5 },
                                    isLandscape: false
                                )
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 90)
                    }
                    .frame(width: screenGeo.size.width, height: screenGeo.size.height * 0.54)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    // MARK: - Cinema Showcase Section
    
    private func cinemaShowcaseSection(screenGeo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Pill
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    
                    Text("NOW IN THEATRES")
                        .font(.system(size: 12, weight: .black))
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
                            Capsule()
                                .stroke(Color.red.opacity(0.35), lineWidth: 1)
                        )
                )
                
                Text("GLOBAL BOX OFFICE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.55))
            }
            
            // Hero Metadata
            if let hero = currentHero {
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
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
                    
                    if !hero.overview.isEmpty {
                        Text(hero.overview)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .lineSpacing(2)
                            .frame(maxWidth: 720, alignment: .leading)
                    }
                    
                    HStack(spacing: 14) {
                        Button {
                            selectedItem = hero
                        } label: {
                            CinemaHeroPrimaryButtonLabel()
                        }
                        .buttonStyle(.tvCard)
                        
                        Button {
                            watchlist.toggleWatchlist(item: hero)
                        } label: {
                            CinemaHeroBookmarkButtonLabel(isBookmarked: watchlist.contains(id: hero.id))
                        }
                        .buttonStyle(.tvCard)
                    }
                    .padding(.top, 4)
                }
                .animation(.easeInOut(duration: 0.28), value: hero.id)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 38)
    }
    
    // MARK: - Cinema Row
    
    private func cinemaRow(title: String, subtitle: String?, items: [MediaItem], isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            if isLandscape {
                                TVLandscapeCardView(
                                    item: item,
                                    width: 380,
                                    subtitle: item.releaseDate ?? "Coming Soon"
                                ) { focused in
                                    handleCardFocus(focused)
                                }
                            } else {
                                TVMediaCardView(
                                    item: item,
                                    width: 210,
                                    showCinemaBadge: true
                                ) { focused in
                                    handleCardFocus(focused)
                                }
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
        withAnimation(.easeInOut(duration: 0.28)) {
            self.focusedItem = item
        }
    }
}

// MARK: - Focusable Buttons

private struct CinemaHeroPrimaryButtonLabel: View {
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
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}

private struct CinemaHeroBookmarkButtonLabel: View {
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
        .animation(.spring(response: 0.2, dampingFraction: 0.85), value: isFocused)
    }
}
