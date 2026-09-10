import Foundation

public protocol ContentProvider: Sendable {
    func fetchHeroSpotlights() async -> [MediaItem]
    func fetchTrending(type: MediaType?) async -> [MediaItem]
    func fetchInCinemas() async -> [MediaItem]
    func fetchUpcomingCinemas() async -> [MediaItem]
    func fetchStreaming(provider: StreamingProvider) async -> [MediaItem]
    func fetchWatchAvailability(id: Int, mediaType: MediaType, region: String) async -> WatchAvailability
    func fetchMovies(category: String) async -> [MediaItem]
    func fetchTVShows(category: String) async -> [MediaItem]
    func search(query: String) async -> [MediaItem]
    func fetchCredits(id: Int, mediaType: MediaType) async -> [CastMember]
    func fetchVideos(id: Int, mediaType: MediaType) async -> [VideoTrailer]
    func fetchRecommendations(id: Int, mediaType: MediaType) async -> [MediaItem]
}
