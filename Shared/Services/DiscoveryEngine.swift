import Foundation
import Combine

@MainActor
public final class DiscoveryEngine: ObservableObject {
    public static let shared = DiscoveryEngine()
    
    @Published public var cinemaMovies: [MediaItem] = []
    @Published public var trendingItems: [MediaItem] = []
    @Published public var streamingItems: [MediaItem] = []
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
        
        async let cinemaTask = tmdb.fetchCinemaMovies()
        async let trendingTask = tmdb.fetchTrending()
        async let streamingTask = tmdb.fetchStreaming(provider: selectedProvider)
        async let newReleasesTask = tmdb.fetchNewReleases()
        async let topRatedTask = tmdb.fetchTopRated()
        async let upcomingTask = tmdb.fetchUpcoming()
        
        self.cinemaMovies = await cinemaTask
        self.trendingItems = await trendingTask
        self.streamingItems = await streamingTask
        self.newReleases = await newReleasesTask
        self.topRated = await topRatedTask
        self.upcoming = await upcomingTask
        
        // Build Top 10 List
        var candidates = self.trendingItems + self.cinemaMovies + self.topRated
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
    
    public func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.searchResults = []
            return
        }
        self.searchResults = await tmdb.search(query: query)
    }
}
