import SwiftUI

public struct TVMediaDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var engine = DiscoveryEngine.shared
    
    @State private var availability: WatchAvailability?
    @State private var castMembers: [CastMember] = []
    @State private var trailers: [VideoTrailer] = []
    @State private var liveRecommendations: [MediaItem] = []
    @State private var selectedRecommendation: MediaItem?
    
    public init(item: MediaItem) {
        self.item = item
    }
    
    private var fallbackRecommendations: [MediaItem] {
        let pool = engine.trendingItems + engine.cinemaNow + engine.popularMovies
        return pool.filter { $0.id != item.id && $0.mediaType == item.mediaType }.prefix(8).map { $0 }
    }
    
    public var body: some View {
        ZStack {
            // Full-screen ambient backdrop
            CachedAsyncImage(url: item.backdropURL(size: "original"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.6), location: 0.0),
                            .init(color: Color.black.opacity(0.88), location: 0.5),
                            .init(color: Color.black, location: 0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 44) {
                    // Top Bar / Dismiss button
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    
                    // Main Showcase: Poster + Details
                    HStack(alignment: .top, spacing: 50) {
                        // Poster column
                        CachedAsyncImage(url: item.posterURL(size: "w500"))
                            .frame(width: 320, height: 480)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.85), radius: 32, x: 0, y: 16)
                        
                        // Metadata & Where to Watch column
                        VStack(alignment: .leading, spacing: 20) {
                            if let tagline = item.tagline, !tagline.isEmpty {
                                Text(tagline.uppercased())
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(1.8)
                                    .foregroundColor(Color.red)
                            }
                            
                            Text(item.title)
                                .font(.system(size: 46, weight: .heavy))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            // Info line
                            HStack(spacing: 14) {
                                if !item.formattedRating.isEmpty {
                                    RatingBadge(rating: item.formattedRating)
                                }
                                
                                if !item.yearString.isEmpty {
                                    Text(item.yearString)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                
                                if !item.formattedRuntime.isEmpty {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.35))
                                    Text(item.formattedRuntime)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                                
                                if let cert = item.certification {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.35))
                                    Text(cert)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.4), lineWidth: 1))
                                }
                                
                                if let genre = item.genreNames.first {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.35))
                                    Text(genre)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                            }
                            
                            // Action Buttons
                            HStack(spacing: 18) {
                                Button {
                                    watchlist.toggleWatchlist(item: item)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: watchlist.contains(id: item.id) ? "checkmark" : "plus")
                                            .font(.system(size: 17, weight: .bold))
                                        Text(watchlist.contains(id: item.id) ? "In My List" : "Add to My List")
                                            .font(.system(size: 17, weight: .bold))
                                    }
                                    .padding(.horizontal, 26)
                                    .padding(.vertical, 14)
                                }
                                
                                if let trailer = (trailers.first ?? item.trailers.first), let url = trailer.youtubeURL {
                                    Link(destination: url) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 17, weight: .bold))
                                            Text("Watch Trailer")
                                                .font(.system(size: 17, weight: .bold))
                                        }
                                        .padding(.horizontal, 26)
                                        .padding(.vertical, 14)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Where to Watch (UK / GB Region)
                            whereToWatchSection
                            
                            // Synopsis
                            if !item.overview.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("SYNOPSIS")
                                        .font(.system(size: 12, weight: .black))
                                        .tracking(1.4)
                                        .foregroundColor(.white.opacity(0.45))
                                    
                                    Text(item.overview)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(5)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    
                    // Cast Section (Live from TMDB)
                    let activeCast = castMembers.isEmpty ? item.cast : castMembers
                    if !activeCast.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Cast")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 24) {
                                    ForEach(activeCast) { member in
                                        castCard(member)
                                    }
                                }
                                .padding(.horizontal, 60)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // More Like This (Live from TMDB)
                    let activeRecs = liveRecommendations.isEmpty ? fallbackRecommendations : liveRecommendations
                    if !activeRecs.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("More Like This")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 28) {
                                    ForEach(activeRecs) { rec in
                                        Button {
                                            selectedRecommendation = rec
                                        } label: {
                                            TVMediaCardView(item: rec, width: 200)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 60)
                                .padding(.vertical, 14)
                            }
                        }
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .task(id: item.id) {
            async let availTask = engine.fetchAvailability(for: item)
            async let castTask = engine.fetchCredits(for: item)
            async let videoTask = engine.fetchVideos(for: item)
            async let recTask = engine.fetchRecommendations(for: item)
            
            self.availability = await availTask
            let c = await castTask
            if !c.isEmpty { self.castMembers = c }
            let v = await videoTask
            if !v.isEmpty { self.trailers = v }
            let r = await recTask
            if !r.isEmpty { self.liveRecommendations = r }
        }
        .fullScreenCover(item: $selectedRecommendation) { rec in
            TVMediaDetailView(item: rec)
        }
    }
    
    // MARK: - Where to Watch Section
    
    private var whereToWatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE TO WATCH")
                .font(.system(size: 12, weight: .black))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.45))
            
            // Theatrical status
            if item.inCinemas || availability?.cinemaStatus != nil {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(availability?.cinemaStatus ?? "Now playing in cinemas")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.2)))
            }
            
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
            
            // Rent Options
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
            
            // Buy Options
            if let buy = availability?.buyOptions, !buy.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Buy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 12) {
                        ForEach(buy) { option in
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
            
            // JustWatch attribution
            Text(availability?.attribution ?? "Streaming data provided by JustWatch & TMDB")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.1).opacity(0.65))
        )
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
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }
}
