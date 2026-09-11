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
    
    public init(item: MediaItem) {
        self.item = item
        self._currentItem = State(initialValue: item)
    }
    
    private var fallbackRecommendations: [MediaItem] {
        let pool = engine.trendingItems + engine.cinemaNow + engine.popularMovies
        return pool.filter { $0.id != item.id && $0.mediaType == item.mediaType }.prefix(8).map { $0 }
    }
    
    public var body: some View {
        ZStack {
            // Ambient Pure Black Background
            Color.black.ignoresSafeArea()
            
            // Full-bleed Ambient Color Bleed & 4K Backdrop
            ZStack {
                // Ambient blurred color bleed
                CachedAsyncImage(url: item.backdropURL(size: "w780"), contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 80)
                    .opacity(0.38)
                    .clipped()
                
                // Crisp 4K Backdrop
                CachedAsyncImage(url: item.backdropURL(size: "original"), contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
                
                // Fluid multi-stop gradient fade blending into lower content
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.clear, location: 0.25),
                        .init(color: Color.black.opacity(0.30), location: 0.45),
                        .init(color: Color.black.opacity(0.70), location: 0.65),
                        .init(color: Color.black.opacity(0.95), location: 0.85),
                        .init(color: Color.black, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 38) {
                    // Top Back Navigation
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            TVBackButtonLabel()
                        }
                        .buttonStyle(.tvCard)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    
                    // Hero Showcase Header (Matching Image 3)
                    heroHeaderSection
                        .padding(.horizontal, 60)
                    
                    // Season Selector & Episode Grid (For TV Shows - Matching Images 1 & 3)
                    if item.mediaType == .tvShow {
                        tvShowSeasonsAndEpisodesSection
                    }
                    
                    // Dedicated Trailers Carousel (Matching Image 1)
                    trailersCarouselSection
                    
                    // Where to Watch Section (Global Providers & Streaming)
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
    
    // MARK: - Hero Header Section (Image 3)
    
    private var heroHeaderSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Title Treatment
            Text(currentItem.title.uppercased())
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(1.0)
                .shadow(color: Color.black.opacity(0.8), radius: 6, x: 0, y: 3)
            
            // Metadata Line (Rating in vibrant green, Year, Genre, Certification, Runtime)
            HStack(spacing: 14) {
                if !currentItem.formattedRating.isEmpty {
                    Text(currentItem.formattedRating)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.4))
                }
                
                if !currentItem.yearString.isEmpty {
                    Text(currentItem.yearString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                if let genre = currentItem.genreNames.first {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(genre)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                if let cert = currentItem.certification {
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
                
                if !currentItem.formattedRuntime.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(currentItem.formattedRuntime)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            
            // Action Buttons & Overview Line (Image 3)
            HStack(alignment: .top, spacing: 28) {
                HStack(spacing: 14) {
                    // Primary White Action Button: Play / Watch Trailer
                    Button {
                        if let trailer = (trailers.first ?? currentItem.trailers.first), let url = trailer.youtubeURL {
                            openURL(url)
                        }
                    } label: {
                        TVPlayButtonLabel()
                    }
                    .buttonStyle(.tvCard)
                    
                    // Secondary Bookmark Button
                    Button {
                        watchlist.toggleWatchlist(item: currentItem)
                    } label: {
                        TVBookmarkButtonLabel(isBookmarked: watchlist.contains(id: currentItem.id))
                    }
                    .buttonStyle(.tvCard)
                }
                
                // Synopsis to the right
                if !currentItem.overview.isEmpty {
                    Text(currentItem.overview)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(3)
                        .lineSpacing(3)
                        .frame(maxWidth: 820, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
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
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }
    
    // MARK: - Where to Watch Section
    
    private var whereToWatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE TO WATCH")
                .font(.system(size: 12, weight: .black))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.45))
            
            // Subscriptions
            if let subs = availability?.subscriptions, !subs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Included with Subscription")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
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
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 16).fill(sub.brandColor.opacity(0.25)))
                        }
                    }
                }
            }
            
            // Rent & Buy Options
            if let rent = availability?.rentOptions, !rent.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rent in 4K")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 12) {
                        ForEach(rent) { option in
                            HStack(spacing: 6) {
                                Text(option.providerName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(option.price)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))
                        }
                    }
                }
            }
            
            // Attribution
            Text(availability?.attribution ?? "Streaming data provided by JustWatch & TMDB")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: 820, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
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
