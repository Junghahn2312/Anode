import SwiftUI

public struct TVCategoryBrowseView: View {
    let mediaType: MediaType
    
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var selectedItem: MediaItem?
    
    public init(mediaType: MediaType) {
        self.mediaType = mediaType
    }
    
    private var isMovie: Bool {
        mediaType == .movie
    }
    
    private var title: String {
        isMovie ? "Movies" : "TV Shows"
    }
    
    private var subtitle: String {
        isMovie
            ? "Discover films currently showing in theatres and streaming worldwide."
            : "Explore series, limited dramas, and television across on-demand platforms."
    }
    
    private var filteredItems: [MediaItem] {
        if isMovie {
            return (engine.popularMovies.isEmpty ? engine.cinemaNow + engine.trendingItems : engine.popularMovies)
                .filter { $0.mediaType == .movie }
        } else {
            return (engine.popularTV.isEmpty ? engine.trendingItems : engine.popularTV)
                .filter { $0.mediaType == .tvShow }
        }
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 36) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(maxWidth: 800, alignment: .leading)
                }
                .padding(.horizontal, 60)
                .padding(.top, 48)
                
                // Featured Hero for this Category
                if let featured = filteredItems.first {
                    categoryHero(featured)
                        .padding(.horizontal, 60)
                }
                
                // Trending Row
                categoryRow(
                    title: isMovie ? "Trending Movies" : "Trending Series",
                    items: filteredItems
                )
                
                // Top Rated Row
                let topRated = filteredItems.filter { $0.rating >= 7.6 }
                if !topRated.isEmpty {
                    categoryRow(
                        title: "Critically Acclaimed",
                        items: topRated
                    )
                }
                
                // Coming Soon or New
                let upcoming = (isMovie ? engine.upcoming : engine.newReleases).filter { $0.mediaType == mediaType }
                if !upcoming.isEmpty {
                    categoryRow(
                        title: isMovie ? "Coming Soon to Theatres" : "New Seasons & Releases",
                        items: upcoming
                    )
                }
            }
            .padding(.bottom, 80)
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    private func categoryHero(_ item: MediaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: item.backdropURL(size: "original"))
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.2),
                                .init(color: Color.black.opacity(0.85), location: 0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("SPOTLIGHT")
                            .font(.system(size: 11, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                        
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                        }
                    }
                    
                    Text(item.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(item.overview)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                        .frame(maxWidth: 680, alignment: .leading)
                }
                .padding(32)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func categoryRow(title: String, items: [MediaItem]) -> some View {
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
                            TVMediaCardView(item: item, width: 210)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
    }
}
