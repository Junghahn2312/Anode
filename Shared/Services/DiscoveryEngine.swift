import Foundation
import Combine

@MainActor
public final class DiscoveryEngine: ObservableObject {
    public static let shared = DiscoveryEngine()
    
    @Published public var heroSpotlights: [MediaItem] = []
    @Published public var cinemaMovies: [MediaItem] = []
    @Published public var cinemaNow: [MediaItem] = []
    @Published public var cinemaUpcoming: [MediaItem] = []
    @Published public var cinemaAndStreaming: [MediaItem] = []
    @Published public var exclusiveCinemaNow: [MediaItem] = []
    @Published public var exclusiveCinemaUpcoming: [MediaItem] = []
    @Published public var freshFromTheatres: [MediaItem] = []
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
    @Published public var homeHeroIndex: Int = 0
    @Published public var cinemaHeroIndex: Int = 0
    
    @Published public var selectedProvider: StreamingProvider = .netflix {
        didSet {
            Task { await loadStreamingItems() }
        }
    }
    
    @Published public var searchResults: [MediaItem] = []
    @Published public var searchMovieResults: [MediaItem] = []
    @Published public var searchTVResults: [MediaItem] = []
    @Published public var searchPeopleResults: [CastMember] = []
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
        async let cinemaAndStreamingTask = tmdb.fetchInCinemasAndStreaming()
        async let freshTask = tmdb.fetchFreshFromTheatres()
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
        
        // Strict theatrical exclusivity: zero streaming availability
        let rawCinema = await cinemaTask
        let rawCinemaUp = await cinemaUpTask
        let strictlyExclusiveCinema = rawCinema.filter { $0.isNowPlayingTheatrical }
        let strictlyExclusiveUpcoming = rawCinemaUp.filter { $0.isUpcomingTheatrical }
        
        self.cinemaNow = strictlyExclusiveCinema
        self.cinemaMovies = strictlyExclusiveCinema
        self.cinemaUpcoming = strictlyExclusiveUpcoming
        self.cinemaAndStreaming = await cinemaAndStreamingTask
        self.exclusiveCinemaNow = strictlyExclusiveCinema
        self.exclusiveCinemaUpcoming = strictlyExclusiveUpcoming
        self.freshFromTheatres = await freshTask
        
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
    
    public func isTheatricalExclusive(_ item: MediaItem) -> Bool {
        tmdb.isTheatricalExclusive(item)
    }
    
    public func loadPlatformTopMovies(provider: StreamingProvider) async -> [MediaItem] {
        await tmdb.fetchPlatformTopMovies(provider: provider)
    }
    
    public func loadPlatformTopTV(provider: StreamingProvider) async -> [MediaItem] {
        await tmdb.fetchPlatformTopTV(provider: provider)
    }
    
    public func loadPlatformNew(provider: StreamingProvider) async -> [MediaItem] {
        await tmdb.fetchPlatformNew(provider: provider)
    }
    
    public func loadStreamingItems() async {
        self.streamingItems = await tmdb.fetchStreaming(provider: selectedProvider)
    }
    
    public func fetchAvailability(for item: MediaItem) async -> WatchAvailability {
        await tmdb.fetchWatchAvailability(id: item.id, mediaType: item.mediaType, region: "GB")
    }
    
    public func enrichItem(_ item: MediaItem) async -> MediaItem {
        await tmdb.enrichMediaItem(item)
    }
    
    public func fetchLogo(for item: MediaItem) async -> String? {
        await tmdb.fetchLogo(for: item)
    }
    
    public func fetchCredits(for item: MediaItem) async -> [CastMember] {
        await tmdb.fetchCredits(id: item.id, mediaType: item.mediaType)
    }
    
    public func fetchPersonCredits(personId: Int, personName: String? = nil) async -> (movies: [MediaItem], tvShows: [MediaItem]) {
        await tmdb.fetchPersonCredits(personId: personId, personName: personName)
    }
    
    public func fetchPersonDetail(personId: Int, personName: String? = nil) async -> PersonDetail? {
        await tmdb.fetchPersonDetail(personId: personId, personName: personName)
    }
    
    public func fetchVideos(for item: MediaItem) async -> [VideoTrailer] {
        await tmdb.fetchVideos(id: item.id, mediaType: item.mediaType)
    }
    
    public func fetchRecommendations(for item: MediaItem) async -> [MediaItem] {
        await tmdb.fetchRecommendations(id: item.id, mediaType: item.mediaType)
    }
    
    public func fetchSeasons(for item: MediaItem) async -> [TVSeason] {
        guard item.mediaType == .tvShow else { return [] }
        return await tmdb.fetchSeasons(tvShowId: item.id)
    }
    
    public func fetchEpisodes(for item: MediaItem, seasonNumber: Int) async -> [TVEpisode] {
        guard item.mediaType == .tvShow else { return [] }
        return await tmdb.fetchEpisodes(tvShowId: item.id, seasonNumber: seasonNumber)
    }
    
    public func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.searchResults = []
            self.searchMovieResults = []
            self.searchTVResults = []
            self.searchPeopleResults = []
            return
        }
        
        async let allTask = tmdb.search(query: query)
        async let peopleTask = tmdb.searchPeople(query: query)
        
        let all = await allTask
        let people = await peopleTask
        
        self.searchResults = all
        self.searchMovieResults = all.filter { $0.mediaType == .movie }
        self.searchTVResults = all.filter { $0.mediaType == .tvShow }
        self.searchPeopleResults = people
    }
}
