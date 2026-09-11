import SwiftUI

public struct TVMediaDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var engine = DiscoveryEngine.shared
    
    @State private var availability: WatchAvailability?
    @State private var castMembers: [CastMember] = []
    @State private var trailers: [VideoTrailer] = []
    @State private var liveRecommendations: [MediaItem] = []
    @State private var selectedRecommendation: MediaItem?
    
    // TV Show Seasons & Episodes State
    @State private var seasons: [TVSeason] = []
    @State private var selectedSeasonNumber: Int = 1
    @State private var episodes: [TVEpisode] = []
    @State private var isLoadingEpisodes: Bool = false
    @State private var currentItem: MediaItem
    @FocusState private var isHeroPlayFocused: Bool
    @FocusState private var isBackFocused: Bool
    
    public init(item: MediaItem) {
        self.item = item
        self._currentItem = State(initialValue: item)
    }
    
    private var fallbackRecommendations: [MediaItem] {
        let pool = engine.trendingItems + engine.cinemaNow + engine.popularMovies
        return pool.filter { $0.id != item.id && $0.mediaType == item.mediaType }.prefix(8).map { $0 }
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Ambient Pure Black Background
                Color.black.ignoresSafeArea()
                
                // Root Vertical ScrollView
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 38) {
                        // Big Hero Section (Takes full initial presence like Home Hero)
                        detailHeroShowcaseSection(screenWidth: screenWidth, screenHeight: screenHeight)
                        
                        // Content Below the Hero Fold
                        VStack(alignment: .leading, spacing: 38) {
                            if item.mediaType == .tvShow {
                                // Season Selector & Episode Grid (TV Shows)
                                tvShowSeasonsAndEpisodesSection
                                
                                // Dedicated Trailers Carousel (underneath seasons & episodes)
                                trailersCarouselSection
                            } else {
                                // Dedicated Trailers Carousel (Movies)
                                trailersCarouselSection
                            }
                            
                            // Where to Watch Section (Platforms only, zero prices, zero attributions)
                            whereToWatchSection
                                .padding(.horizontal, 60)
                            
                            // Cast Rail
                            castRailSection
                            
                            // More Like This
                            moreLikeThisSection
                        }
                        .padding(.bottom, 90)
                    }
                }
                .ignoresSafeArea()
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .task(id: item.id) {
            async let enrichTask = engine.enrichItem(item)
            async let availTask = engine.fetchAvailability(for: item)
            async let castTask = engine.fetchCredits(for: item)
            async let videoTask = engine.fetchVideos(for: item)
            async let recTask = engine.fetchRecommendations(for: item)
            
            let enriched = await enrichTask
            self.currentItem = enriched
            self.availability = await availTask
            let c = await castTask
            if !c.isEmpty { self.castMembers = c }
            let v = await videoTask
            if !v.isEmpty { self.trailers = v }
            let r = await recTask
            if !r.isEmpty { self.liveRecommendations = r }
            
            if item.mediaType == .tvShow {
                let s = await engine.fetchSeasons(for: item)
                self.seasons = s
                let firstSeason = s.first(where: { $0.seasonNumber > 0 })?.seasonNumber ?? s.first?.seasonNumber ?? 1
                self.selectedSeasonNumber = firstSeason
                await loadEpisodes(for: firstSeason)
            }
        }
        .fullScreenCover(item: $selectedRecommendation) { rec in
            TVMediaDetailView(item: rec)
        }
    }
    
    // MARK: - Massive Hero Showcase Section (Matching Home Hero Presence)
    
    private func detailHeroShowcaseSection(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed Backdrop & Vignettes
            ZStack {
                // Ambient color bleed
                CachedAsyncImage(url: currentItem.backdropURL(size: "w780"), contentMode: .fill)
                    .frame(width: screenWidth, height: 860)
                    .blur(radius: 80)
                    .opacity(0.38)
                    .clipped()
                
                // Crisp 4K Backdrop
                let backdrop = currentItem.backdropURL(size: "original") ?? currentItem.posterURL(size: "original")
                CachedAsyncImage(url: backdrop, contentMode: .fill)
                    .frame(width: screenWidth, height: 860, alignment: .top)
                    .clipped()
                
                // Soft left vignette for logo & typography legibility
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.85), location: 0.0),
                        .init(color: Color.black.opacity(0.40), location: 0.45),
                        .init(color: Color.clear, location: 0.70)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Soft top vignette for back button legibility
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.70), location: 0.0),
                        .init(color: Color.clear, location: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Bottom fade blending seamlessly into trailers and lower content
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.35),
                        .init(color: Color.black.opacity(0.60), location: 0.70),
                        .init(color: Color.black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: screenWidth, height: 860)
            .clipped()
            
            // Top Back Navigation Button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        TVBackButtonLabel()
                    }
                    .buttonStyle(.tvCard)
                    .focused($isBackFocused)
                    Spacer()
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                Spacer()
            }
            .frame(width: screenWidth, height: 860)
            
            // Hero Metadata, Logo Artwork & Action Buttons
            VStack(alignment: .leading, spacing: 18) {
                // ClearArt Transparent Logo Artwork or Stylized Title
                Group {
                    if let logoPath = currentItem.logoPath,
                       let logoURL = URL(string: logoPath.hasPrefix("http") ? logoPath : "https://image.tmdb.org/t/p/w500\(logoPath)") {
                        CachedAsyncImage(url: logoURL, contentMode: .fit)
                            .frame(maxHeight: 120, alignment: .leading)
                            .shadow(color: Color.black.opacity(0.90), radius: 8, x: 0, y: 3)
                    } else {
                        Text(currentItem.title.uppercased())
                            .font(.system(size: 52, weight: .heavy, design: .serif))
                            .foregroundColor(Color.white)
                            .tracking(1.0)
                            .shadow(color: Color.black.opacity(0.90), radius: 8, x: 0, y: 3)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                
                // Metadata Line (Year • Genre • Runtime • Certification • Rating)
                HStack(spacing: 12) {
                    if !currentItem.yearString.isEmpty {
                        Text(currentItem.yearString)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    
                    if let genre = currentItem.genreNames.first {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        Text(genre)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    
                    if !currentItem.formattedRuntime.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        Text(currentItem.formattedRuntime)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                    }
                    
                    if let cert = currentItem.certification {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        Text(cert)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.40), lineWidth: 1)
                            )
                    }
                    
                    if !currentItem.formattedRating.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        RatingBadge(rating: currentItem.formattedRating)
                    }
                }
                
                // Synopsis Overview
                if !currentItem.overview.isEmpty {
                    Text(currentItem.overview)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(3)
                        .lineSpacing(4)
                        .frame(maxWidth: 820, alignment: .leading)
                }
                
                // Action Buttons: Play / Watch Trailer + In My List
                HStack(spacing: 16) {
                    Button {
                        if let trailer = (trailers.first ?? currentItem.trailers.first), let url = trailer.youtubeURL {
                            openURL(url)
                        }
                    } label: {
                        TVPlayButtonLabel()
                    }
                    .buttonStyle(.tvCard)
                    .focused($isHeroPlayFocused)
                    .onMoveCommand { direction in
                        if direction == .up {
                            isBackFocused = true
                        }
                    }
                    
                    Button {
                        watchlist.toggleWatchlist(item: currentItem)
                    } label: {
                        TVBookmarkButtonLabel(isBookmarked: watchlist.contains(id: currentItem.id))
                    }
                    .buttonStyle(.tvCard)
                    .onMoveCommand { direction in
                        if direction == .up {
                            isBackFocused = true
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 50)
        }
        .frame(width: screenWidth, height: 860)
    }
    
    // MARK: - Season Selector & Episodes Section (Images 1 & 3)
    
    private var tvShowSeasonsAndEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Season Selector Tabs (Specials, Season 1, Season 2, etc.)
            if !seasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(seasons) { season in
                            Button {
                                selectedSeasonNumber = season.seasonNumber
                                Task { await loadEpisodes(for: season.seasonNumber) }
                            } label: {
                                SeasonTabLabel(
                                    season: season,
                                    isSelected: selectedSeasonNumber == season.seasonNumber
                                )
                            }
                            .buttonStyle(.tvCard)
                            .onMoveCommand { direction in
                                if direction == .up {
                                    isHeroPlayFocused = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                }
            }
            
            // Episode Cards Carousel (Image 1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                        Button {
                            if let idx = episodes.firstIndex(where: { $0.id == episode.id }) {
                                episodes[idx].isWatched.toggle()
                            }
                        } label: {
                            TVEpisodeCardView(episode: episode)
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 14)
            }
        }
    }
    
    private func loadEpisodes(for seasonNumber: Int) async {
        isLoadingEpisodes = true
        let list = await engine.fetchEpisodes(for: item, seasonNumber: seasonNumber)
        self.episodes = list
        self.isLoadingEpisodes = false
    }
    
    // MARK: - Trailers Carousel Section (Image 1)
    
    private var trailersCarouselSection: some View {
        let activeTrailers = trailers.isEmpty ? item.trailers : trailers
        return Group {
            if !activeTrailers.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Trailers")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 26) {
                            ForEach(Array(activeTrailers.enumerated()), id: \.element.id) { index, trailer in
                                Button {
                                    if let url = trailer.youtubeURL {
                                        openURL(url)
                                    }
                                } label: {
                                    TVTrailerCardView(
                                        trailer: trailer,
                                        label: "Trailer \(index + 1)",
                                        backdropURL: item.backdropURL(size: "w780")
                                    )
                                }
                                .buttonStyle(.tvCard)
                                .onMoveCommand { direction in
                                    if direction == .up && item.mediaType != .tvShow {
                                        isHeroPlayFocused = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }
    
    // MARK: - Where to Watch Section (Zero Prices, Zero Attributions)
    
    private var whereToWatchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHERE TO WATCH")
                .font(.system(size: 13, weight: .black))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.50))
            
            // Subscriptions / Streaming platforms
            if let subs = availability?.subscriptions, !subs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stream On")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    
                    HStack(spacing: 12) {
                        ForEach(subs, id: \.id) { sub in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(sub.brandColor)
                                    .frame(width: 8, height: 8)
                                Text(sub.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(sub.brandColor.opacity(0.25)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(sub.brandColor.opacity(0.50), lineWidth: 1))
                        }
                    }
                }
            }
            
            // Purchase / Rent Platforms - NO PRICES, ONLY PROVIDER NAMES
            let rentOrBuy = (availability?.rentOptions ?? []) + (availability?.buyOptions ?? [])
            let uniqueProviders: [PurchaseOption] = {
                var seen = Set<String>()
                var list: [PurchaseOption] = []
                for opt in rentOrBuy {
                    if !seen.contains(opt.providerName) {
                        seen.insert(opt.providerName)
                        list.append(opt)
                    }
                }
                return list
            }()
            
            if !uniqueProviders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rent or Buy")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    
                    HStack(spacing: 12) {
                        ForEach(uniqueProviders) { option in
                            HStack(spacing: 6) {
                                Image(systemName: "tv")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.70))
                                Text(option.providerName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.18), lineWidth: 1))
                        }
                    }
                }
            }
            
            if (availability?.subscriptions.isEmpty ?? true) && uniqueProviders.isEmpty {
                Text("Check streaming apps or local listings for release availability.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(24)
        .frame(maxWidth: 860, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Cast Rail Section
    
    private var castRailSection: some View {
        let activeCast = castMembers.isEmpty ? item.cast : castMembers
        return Group {
            if !activeCast.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cast")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 20) {
                            ForEach(activeCast) { member in
                                castCard(member)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    private func castCard(_ member: CastMember) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: member.profileURL)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text(member.character)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - More Like This Section
    
    private var moreLikeThisSection: some View {
        let activeRecs = liveRecommendations.isEmpty ? fallbackRecommendations : liveRecommendations
        return Group {
            if !activeRecs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("More Like This")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 60)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 32) {
                            ForEach(activeRecs) { rec in
                                Button {
                                    selectedRecommendation = rec
                                } label: {
                                    TVMediaCardView(item: rec, width: 210)
                                }
                                .buttonStyle(.tvCard)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 24)
                    }
                }
            }
        }
    }
}

// MARK: - Dedicated Focusable Button Labels & Helper Views

private struct TVBackButtonLabel: View {
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
            Text("Back")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isFocused ? Color.white : Color.white.opacity(0.18))
                .background(
                    Group {
                        if !isFocused {
                            Capsule().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(isFocused ? Color.clear : Color.white.opacity(0.25), lineWidth: 1)
                )
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}

private struct TVPlayButtonLabel: View {
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.fill")
                .font(.system(size: 17, weight: .black))
            Text("Play")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundColor(.black)
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
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .shadow(color: Color.white.opacity(isFocused ? 0.35 : 0.0), radius: isFocused ? 12 : 0, x: 0, y: 0)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}

private struct TVBookmarkButtonLabel: View {
    let isBookmarked: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isFocused ? Color(white: 0.35) : Color.white.opacity(0.18))
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
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}

private struct SeasonTabLabel: View {
    let season: TVSeason
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        Text(season.name)
            .font(.system(size: 17, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected || isFocused ? .white : .white.opacity(0.65))
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color(white: 0.35) : (isSelected ? Color(white: 0.24) : Color.clear))
                    .background(
                        Group {
                            if !isFocused && !isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial)
                            }
                        }
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Color(white: 0.65).opacity(0.8) : Color.white.opacity(0.14), lineWidth: 1.2)
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}

// MARK: - TV Episode Card View (Matching Image 1)

private struct TVEpisodeCardView: View {
    let episode: TVEpisode
    @Environment(\.isFocused) private var isFocused: Bool
    
    private let cardWidth: CGFloat = 340
    private var cardHeight: CGFloat { cardWidth * 9.0 / 16.0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 16:9 Thumbnail with Watched Checkmark in Top-Left
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: episode.stillURL(size: "w780"))
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Focus Outline
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color(white: 0.65).opacity(0.85) : Color.clear, lineWidth: 2)
                
                // Watched Checkmark Circle (Image 1)
                Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(episode.isWatched ? .green : .white.opacity(0.85))
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .padding(12)
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: Color.black.opacity(isFocused ? 0.6 : 0.25), radius: isFocused ? 16 : 6, x: 0, y: isFocused ? 8 : 2)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
            
            // Metadata below card (Image 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Episode \(episode.episodeNumber)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                
                Text(episode.name.uppercased())
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.9))
                    .lineLimit(1)
                
                Text(episode.overview)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .lineSpacing(2)
                
                HStack(spacing: 8) {
                    Text(episode.formattedRuntime)
                    if !episode.formattedAirDate.isEmpty {
                        Text("•")
                        Text(episode.formattedAirDate)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 2)
            }
            .frame(width: cardWidth, alignment: .leading)
        }
    }
}

// MARK: - TV Trailer Card View (Matching Image 1)

private struct TVTrailerCardView: View {
    let trailer: VideoTrailer
    let label: String
    let backdropURL: URL?
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    private let cardWidth: CGFloat = 300
    private var cardHeight: CGFloat { cardWidth * 9.0 / 16.0 }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Thumbnail / Backdrop
            CachedAsyncImage(url: backdropURL)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Dark scrim
            Color.black.opacity(0.35)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Center Play Badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                    Spacer()
                }
                Spacer()
            }
            
            // Bottom-Left Label (e.g. "Trailer 1")
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.7)))
                .padding(12)
            
            // Focus Outline
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color(white: 0.65).opacity(0.85) : Color.clear, lineWidth: 2)
        }
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: Color.black.opacity(isFocused ? 0.6 : 0.25), radius: isFocused ? 16 : 6, x: 0, y: isFocused ? 8 : 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}
