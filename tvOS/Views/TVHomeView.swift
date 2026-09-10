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
        ZStack {
            // Ambient Pure Black Background
            Color.black.ignoresSafeArea()
            
            // 4K Backdrop in top 50%
            if let hero = currentHero {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(url: hero.backdropURL(size: "original"))
                            .frame(width: geo.size.width, height: geo.size.height * 0.54)
                            .clipped()
                            .id(hero.id)
                            .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                        
                        // Left-to-right gradient for text legibility
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.92), location: 0.0),
                                .init(color: Color.black.opacity(0.65), location: 0.35),
                                .init(color: Color.clear, location: 0.75)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width, height: geo.size.height * 0.54)
                        
                        // Top-to-bottom gradient fading to solid black
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.3),
                                .init(color: Color.black.opacity(0.6), location: 0.65),
                                .init(color: Color.black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: geo.size.width, height: geo.size.height * 0.54)
                    }
                }
                .ignoresSafeArea()
            }
            
            // Scrollable Content Rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 38) {
                    // Top Hero Metadata & Actions
                    if let hero = currentHero {
                        heroMetadataView(hero)
                            .padding(.horizontal, 60)
                            .padding(.top, 72)
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
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 60)
                                .padding(.vertical, 14)
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
                    
                    // In Theatres Now
                    if !engine.cinemaNow.isEmpty {
                        contentRow(
                            title: "In Cinemas Now (UK)",
                            items: engine.cinemaNow,
                            showCinemaBadge: true
                        )
                    }
                    
                    // Trending on Netflix UK
                    if !engine.netflixTrending.isEmpty {
                        contentRow(
                            title: "Trending on Netflix",
                            items: engine.netflixTrending
                        )
                    }
                    
                    // Trending on Disney+ UK
                    if !engine.disneyTrending.isEmpty {
                        contentRow(
                            title: "Trending on Disney+",
                            items: engine.disneyTrending
                        )
                    }
                    
                    // Trending on Prime Video UK
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
                    
                    // Coming Soon to Cinemas (16:9 Landscape Variety Row)
                    if !engine.cinemaUpcoming.isEmpty {
                        landscapeRow(
                            title: "Coming Soon to UK Theatres",
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
                .padding(.bottom, 90)
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
        VStack(alignment: .leading, spacing: 14) {
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
                    Text("STREAMING ON \(primarySub.name.uppercased()) (UK)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(primarySub.brandColor.opacity(0.65)))
                } else if let avail = heroAvailability, let rent = avail.rentOptions.first {
                    Text("RENT FROM \(rent.price) (UK)")
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
                .font(.system(size: 46, weight: .heavy))
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
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.82))
                .lineLimit(3)
                .lineSpacing(4)
                .frame(maxWidth: 720, alignment: .leading)
                .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
            
            // Action Buttons
            HStack(spacing: 20) {
                Button {
                    selectedItem = hero
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .bold))
                        Text("View Details")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                
                Button {
                    watchlist.toggleWatchlist(item: hero)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: watchlist.contains(id: hero.id) ? "checkmark" : "plus")
                            .font(.system(size: 17, weight: .bold))
                        Text(watchlist.contains(id: hero.id) ? "In My List" : "Add to My List")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                
                if let trailer = hero.trailers.first, let url = trailer.youtubeURL {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("Watch Trailer")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(minHeight: 250, alignment: .bottomLeading)
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
                .padding(.vertical, 14)
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
                .padding(.vertical, 14)
            }
        }
    }
    
    private func handleCardFocus(_ item: MediaItem) {
        isUserInteracting = true
        focusedItem = item
    }
}
