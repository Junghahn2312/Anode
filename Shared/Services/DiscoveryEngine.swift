import Foundation
import Combine

@MainActor
public final class DiscoveryEngine: ObservableObject {
    public static let shared = DiscoveryEngine()
    
    @Published public var heroSpotlights: [MediaItem] = []
    @Published public var cinemaMovies: [MediaItem] = []
    @Published public var cinemaNow: [MediaItem] = []
    @Published public var cinemaUpcoming: [MediaItem] = []
    @Published public var trendingItems: [MediaItem] = []
    @Published public var streamingItems: [MediaItem] = []
    @Published public var popularMovies: [MediaItem] = []
    @Published public var popularTV: [MediaItem] = []
    @Published public var netflixTrending: [MediaItem] = []
    @Published public var primeTrending: [MediaItem] = []
    @Published public var disneyTrending: [MediaItem] = []
    @Published public var appleTVTrending: [MediaItem] = []
    @Published public var newReleases: [MediaItem] = []
    @Published public var topRated: [MediaItem] = []
    @Published public var upcoming: [MediaItem] = []
    @Published public var topTen: [MediaItem] = []
    @Published public var genres: [GenreCategory] = GenreCategory.allCurated
    
    @Published public var selectedProvider: StreamingProvider = .netflix {
        didSet {
            Task { await loadStreamingItems() }
        }
    }
    
    @Published public var searchResults: [MediaItem] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    
    private let tmdb = TMDBService.shared
    
    public init() {
        Task {
            await loadAll()
        }
    }
    
    public func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        
        async let heroesTask = tmdb.fetchHeroSpotlights()
        async let cinemaTask = tmdb.fetchInCinemas()
        async let cinemaUpTask = tmdb.fetchUpcomingCinemas()
        async let trendingTask = tmdb.fetchTrending(type: nil)
        async let streamingTask = tmdb.fetchStreaming(provider: selectedProvider)
        async let netflixTask = tmdb.fetchStreaming(provider: .netflix)
        async let primeTask = tmdb.fetchStreaming(provider: .primeVideo)
        async let disneyTask = tmdb.fetchStreaming(provider: .disneyPlus)
        async let appleTask = tmdb.fetchStreaming(provider: .appleTV)
        async let moviesTask = tmdb.fetchMovies(category: "popular")
        async let tvTask = tmdb.fetchTVShows(category: "popular")
        async let newReleasesTask = tmdb.fetchNewReleases()
        async let topRatedTask = tmdb.fetchTopRated()
        async let upcomingTask = tmdb.fetchUpcoming()
        
        self.heroSpotlights = await heroesTask
        self.cinemaNow = await cinemaTask
        self.cinemaMovies = self.cinemaNow
        self.cinemaUpcoming = await cinemaUpTask
        self.trendingItems = await trendingTask
        self.streamingItems = await streamingTask
        self.netflixTrending = await netflixTask
        self.primeTrending = await primeTask
        self.disneyTrending = await disneyTask
        self.appleTVTrending = await appleTask
        self.popularMovies = await moviesTask
        self.popularTV = await tvTask
        self.newReleases = await newReleasesTask
        self.topRated = await topRatedTask
        self.upcoming = await upcomingTask
        
        // Build Top 10 List
        let candidates = self.trendingItems + self.cinemaNow + self.topRated
        var unique: [MediaItem] = []
        var seen = Set<Int>()
        for item in candidates {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                var ranked = item
                ranked.rank = unique.count + 1
                unique.append(ranked)
                if unique.count == 10 { break }
            }
        }
        self.topTen = unique
    }
    
    public func loadStreamingItems() async {
        self.streamingItems = await tmdb.fetchStreaming(provider: selectedProvider)
    }
    
    public func fetchAvailability(for item: MediaItem) async -> WatchAvailability {
        await tmdb.fetchWatchAvailability(id: item.id, mediaType: item.mediaType, region: "GB")
    }
    
    public func fetchCredits(for item: MediaItem) async -> [CastMember] {
        await tmdb.fetchCredits(id: item.id, mediaType: item.mediaType)
    }
    
    public func fetchVideos(for item: MediaItem) async -> [VideoTrailer] {
        await tmdb.fetchVideos(id: item.id, mediaType: item.mediaType)
    }
    
    public func fetchRecommendations(for item: MediaItem) async -> [MediaItem] {
        await tmdb.fetchRecommendations(id: item.id, mediaType: item.mediaType)
    }
    
    public func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.searchResults = []
            return
        }
        self.searchResults = await tmdb.search(query: query)
    }
}
