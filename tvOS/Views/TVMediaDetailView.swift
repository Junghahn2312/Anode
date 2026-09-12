import SwiftUI

public struct TVMediaDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var engine = DiscoveryEngine.shared
    
    private enum DetailDestination: Identifiable {
        case recommendation(MediaItem)
        case castMember(CastMember)
        
        var id: String {
            switch self {
            case .recommendation(let item): return "rec-\(item.id)"
            case .castMember(let member): return "cast-\(member.id)"
            }
        }
    }
    
    @State private var availability: WatchAvailability?
    @State private var castMembers: [CastMember] = []
    @State private var trailers: [VideoTrailer] = []
    @State private var liveRecommendations: [MediaItem] = []
    @State private var activeDestination: DetailDestination?
    
    // TV Show Seasons & Episodes State
    @State private var seasons: [TVSeason] = []
    @State private var selectedSeasonNumber: Int = 1
    @State private var episodes: [TVEpisode] = []
    @State private var isLoadingEpisodes: Bool = false
    @State private var currentItem: MediaItem
    @State private var heroTrailerURL: URL? = nil
    @State private var isHeroTrailerPlaying: Bool = false
    @State private var isHeroInView: Bool = true
    @FocusState private var isHeroPlayFocused: Bool
    @FocusState private var isBackFocused: Bool
    @FocusState private var isFirstEpisodeFocused: Bool
    
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
                            .background(
                                GeometryReader { heroGeo in
                                    Color.clear.preference(
                                        key: TVDetailHeroVisibilityKey.self,
                                        value: heroGeo.frame(in: .named("mediaDetailScroll")).maxY
                                    )
                                }
                            )
                        
                        // Content Below the Hero Fold
                        VStack(alignment: .leading, spacing: 38) {
                            if item.mediaType == .tvShow {
                                // Season Selector & Episode Grid (TV Shows)
                                tvShowSeasonsAndEpisodesSection
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
                .coordinateSpace(name: "mediaDetailScroll")
                .onPreferenceChange(TVDetailHeroVisibilityKey.self) { maxY in
                    handleHeroScrollVisibility(maxY: maxY)
                }
                .ignoresSafeArea()
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .task(id: item.id) {
            isHeroTrailerPlaying = false
            heroTrailerURL = nil
            isHeroInView = true
            
            // Resolve trailer stream concurrently and start playing immediately
            Task {
                if let streamURL = await TrailerService.shared.resolveTrailerStream(for: item) {
                    await MainActor.run {
                        self.heroTrailerURL = streamURL
                        if isHeroInView {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                self.isHeroTrailerPlaying = true
                            }
                        }
                    }
                }
            }
            
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
        .onDisappear {
            isHeroTrailerPlaying = false
            heroTrailerURL = nil
        }
        .fullScreenCover(item: $activeDestination) { destination in
            switch destination {
            case .recommendation(let rec):
                TVMediaDetailView(item: rec)
            case .castMember(let member):
                TVPersonDetailView(member: member)
            }
        }
    }
    
    private func handleHeroScrollVisibility(maxY: CGFloat) {
        // Ignore uninitialized or offscreen frames during initial layout
        guard maxY > 0 else { return }
        let visible = maxY > 80
        if visible != isHeroInView {
            isHeroInView = visible
            if !visible {
                if isHeroTrailerPlaying {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isHeroTrailerPlaying = false
                    }
                }
            } else {
                if heroTrailerURL != nil && !isHeroTrailerPlaying {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        isHeroTrailerPlaying = true
                    }
                }
            }
        }
    }
    
    // MARK: - Massive Hero Showcase Section (Matching Home Hero Presence)
    
    private func detailHeroShowcaseSection(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let heroHeight: CGFloat = max(screenHeight * 0.95, 1020)
        return ZStack(alignment: .bottomLeading) {
            // Full-bleed Backdrop & Vignettes
            ZStack {
                // Ambient color bleed
                CachedAsyncImage(url: currentItem.backdropURL(size: "w780"), contentMode: .fill)
                    .frame(width: screenWidth, height: heroHeight)
                    .blur(radius: 80)
                    .opacity(0.38)
                    .clipped()
                
                // Crisp 4K Backdrop
                let backdrop = currentItem.backdropURL(size: "original") ?? currentItem.posterURL(size: "original")
                CachedAsyncImage(url: backdrop, contentMode: .fill)
                    .frame(width: screenWidth, height: heroHeight, alignment: .top)
                    .clipped()
                
                // Live Trailer Video Stream with sound
                if isHeroTrailerPlaying, let heroTrailerURL = heroTrailerURL {
                    TVTrailerPlayerView(videoURL: heroTrailerURL, isMuted: false)
                        .frame(width: screenWidth, height: heroHeight)
                        .clipped()
                        .transition(.opacity)
                }
                
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
                
                // Bottom fade blending seamlessly into lower content
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.55),
                        .init(color: Color.black.opacity(0.60), location: 0.82),
                        .init(color: Color.black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: screenWidth, height: heroHeight)
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
            .frame(width: screenWidth, height: heroHeight)
            
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
            .padding(.bottom, 60)
        }
        .frame(width: screenWidth, height: heroHeight)
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
                        if index == 0 {
                            Button {
                                if let idx = episodes.firstIndex(where: { $0.id == episode.id }) {
                                    episodes[idx].isWatched.toggle()
                                }
                            } label: {
                                TVEpisodeCardView(episode: episode)
                            }
                            .buttonStyle(.tvCard)
                            .focused($isFirstEpisodeFocused)
                            .onMoveCommand { direction in
                                if direction == .up {
                                    isHeroPlayFocused = true
                                }
                            }
                        } else {
                            Button {
                                if let idx = episodes.firstIndex(where: { $0.id == episode.id }) {
                                    episodes[idx].isWatched.toggle()
                                }
                            } label: {
                                TVEpisodeCardView(episode: episode)
                            }
                            .buttonStyle(.tvCard)
                            .onMoveCommand { direction in
                                if direction == .up {
                                    isHeroPlayFocused = true
                                }
                            }
                        }
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
    
    // MARK: - Where to Watch Section (Zero Prices, Zero Attributions)
    
    private var whereToWatchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHERE TO WATCH")
                .font(.system(size: 13, weight: .black))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.50))
            
            // Cinema / In Theatres status directly referencing JustWatch
            if currentItem.inCinemas || availability?.cinemaStatus != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cinema")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("In Theatres")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        if currentItem.isTheatricalExclusive {
                            Text("(Theatrical Exclusive)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.60))
                        } else if currentItem.hasStreamingOptions {
                            Text("(Also Available to Stream)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.60))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.50), lineWidth: 1))
                }
            }
            
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
            
            if (availability?.subscriptions.isEmpty ?? true) && uniqueProviders.isEmpty && !currentItem.inCinemas && availability?.cinemaStatus == nil {
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
                        HStack(spacing: 24) {
                            ForEach(activeCast) { member in
                                TVCastMemberCard(member: member) {
                                    activeDestination = .castMember(member)
                                }
                                .onMoveCommand { direction in
                                    if direction == .up {
                                        if item.mediaType == .tvShow && !episodes.isEmpty {
                                            isFirstEpisodeFocused = true
                                        } else {
                                            isHeroPlayFocused = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                    }
                }
                .focusSection()
            }
        }
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
                                    activeDestination = .recommendation(rec)
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

struct TVBackButtonLabel: View {
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
                .font(.system(size: 17, weight: .bold))
            Text("Play")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.25), lineWidth: isFocused ? 2.5 : 1)
        )
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.5) : Color.clear, radius: 14)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isFocused)
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

// MARK: - Dedicated Interactive Cast Member Card

public struct TVCastMemberCard: View {
    let member: CastMember
    let onSelect: () -> Void
    
    public init(member: CastMember, onSelect: @escaping () -> Void) {
        self.member = member
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            TVCastMemberCardContent(member: member)
        }
        .buttonStyle(.tvCard)
    }
}

private struct TVCastMemberCardContent: View {
    let member: CastMember
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: member.profileURL)
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isFocused ? Color.black.opacity(0.30) : Color.white.opacity(0.18), lineWidth: isFocused ? 2 : 1)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isFocused ? .black : .white)
                    .lineLimit(1)
                
                Text(member.character)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isFocused ? Color.black.opacity(0.75) : Color.white.opacity(0.70))
                    .lineLimit(1)
            }
            .frame(maxWidth: 180, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isFocused ? Color.white : Color.white.opacity(0.15), lineWidth: isFocused ? 2.5 : 1)
                )
        )
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(
            color: isFocused ? Color.white.opacity(0.35) : Color.black.opacity(0.20),
            radius: isFocused ? 16 : 4,
            x: 0,
            y: isFocused ? 8 : 2
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
    }
}

// MARK: - Full Screen Person / Cast Member Filmography View

public struct TVPersonDetailView: View {
    let member: CastMember
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = DiscoveryEngine.shared
    
    @State private var personDetail: PersonDetail?
    @State private var movies: [MediaItem] = []
    @State private var tvShows: [MediaItem] = []
    @State private var isLoading: Bool = true
    @State private var selectedMedia: MediaItem?
    @FocusState private var isBackFocused: Bool
    
    public init(member: CastMember) {
        self.member = member
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Ambient background
                Color(red: 0.04, green: 0.04, blue: 0.06)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 36) {
                        // Top Bar: Back Button
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
                        
                        // Header: Actor Profile Info
                        personHeaderSection
                            .padding(.horizontal, 60)
                        
                        // Movies Section
                        if !movies.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    Text("Movies")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("(\(movies.count))")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .padding(.horizontal, 60)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 28) {
                                        ForEach(movies) { movie in
                                            Button {
                                                selectedMedia = movie
                                            } label: {
                                                TVExpandingMediaCardView(
                                                    item: movie,
                                                    normalWidth: 190,
                                                    showCinemaBadge: movie.inCinemas
                                                )
                                            }
                                            .buttonStyle(.tvCard)
                                        }
                                    }
                                    .padding(.horizontal, 60)
                                    .padding(.vertical, 20)
                                }
                            }
                            .focusSection()
                        }
                        
                        // TV Shows Section
                        if !tvShows.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    Text("TV Shows")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("(\(tvShows.count))")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .padding(.horizontal, 60)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 28) {
                                        ForEach(tvShows) { show in
                                            Button {
                                                selectedMedia = show
                                            } label: {
                                                TVExpandingMediaCardView(
                                                    item: show,
                                                    normalWidth: 190,
                                                    showCinemaBadge: false
                                                )
                                            }
                                            .buttonStyle(.tvCard)
                                        }
                                    }
                                    .padding(.horizontal, 60)
                                    .padding(.vertical, 20)
                                }
                            }
                            .focusSection()
                        }
                        
                        if movies.isEmpty && tvShows.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Text("No titles found for this cast member.")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.60))
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.bottom, 90)
                }
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .task(id: member.id) {
            isLoading = true
            async let detailTask = engine.fetchPersonDetail(personId: member.id, personName: member.name)
            async let creditsTask = engine.fetchPersonCredits(personId: member.id, personName: member.name)
            
            let detail = await detailTask
            let (movieItems, tvItems) = await creditsTask
            
            self.personDetail = detail
            self.movies = movieItems
            self.tvShows = tvItems
            self.isLoading = false
        }
        .fullScreenCover(item: $selectedMedia) { media in
            TVMediaDetailView(item: media)
        }
    }
    
    private var personHeaderSection: some View {
        HStack(alignment: .top, spacing: 32) {
            let photoURL = personDetail?.profileURL ?? member.highResProfileURL ?? member.profileURL
            CachedAsyncImage(url: photoURL)
                .frame(width: 170, height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.70), radius: 14, x: 0, y: 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(personDetail?.name ?? member.name)
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    if let dept = personDetail?.knownForDepartment, !dept.isEmpty {
                        Text("Known for \(dept)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.90, green: 0.70, blue: 0.30))
                    }
                    
                    if let birth = personDetail?.birthday, !birth.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        Text("Born \(birth)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    if let place = personDetail?.placeOfBirth, !place.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.40))
                        Text(place)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                
                if let bio = personDetail?.biography, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                        .lineLimit(5)
                        .frame(maxWidth: 1000, alignment: .leading)
                } else {
                    Text("Acclaimed member of the cast appearing in major film and television productions.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                        .frame(maxWidth: 900, alignment: .leading)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Hero Visibility Scroll Tracking Preference Key

private struct TVDetailHeroVisibilityKey: PreferenceKey {
    static var defaultValue: CGFloat = 1000
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

