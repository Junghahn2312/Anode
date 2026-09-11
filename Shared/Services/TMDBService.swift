import Foundation

public actor TMDBService: ContentProvider {
    public static let shared = TMDBService()
    
    private let baseURL = "https://api.themoviedb.org/3"
    private var apiKey: String = "156d1d139b8cf0ae10b2bce1cb46d9af"
    private var readAccessToken: String = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIxNTZkMWQxMzliOGNmMGFlMTBiMmJjZTFjYjQ2ZDlhZiIsIm5iZiI6MTc1NDY5MjA4Mi44MDQsInN1YiI6IjY4OTY3OWYyNjY4NDVjZTczYzkyZTgyYSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.9k2ye1BA5Ta1bbSW79w5a-L2aNo64ZrwOYhUdeNUeJQ"
    
    private var memoryCache: [String: [MediaItem]] = [:]
    private var availabilityCache: [Int: WatchAvailability] = [:]
    private var creditsCache: [Int: [CastMember]] = [:]
    private var videosCache: [Int: [VideoTrailer]] = [:]
    private var seasonsCache: [Int: [TVSeason]] = [:]
    private var episodesCache: [String: [TVEpisode]] = [:]
    private var logoCache: [Int: String] = [:]
    private var enrichedCache: [Int: MediaItem] = [:]
    
    public func clearMemoryCache() {
        memoryCache.removeAll()
        availabilityCache.removeAll()
        creditsCache.removeAll()
        videosCache.removeAll()
        seasonsCache.removeAll()
        episodesCache.removeAll()
        logoCache.removeAll()
        enrichedCache.removeAll()
    }
    
    private static let genreMap: [Int: String] = [
        28: "Action",
        12: "Adventure",
        16: "Animation",
        35: "Comedy",
        80: "Crime",
        99: "Documentary",
        18: "Drama",
        10751: "Family",
        14: "Fantasy",
        36: "History",
        27: "Horror",
        10402: "Music",
        9648: "Mystery",
        10749: "Romance",
        878: "Sci-Fi",
        10770: "TV Movie",
        53: "Thriller",
        10752: "War",
        37: "Western",
        10759: "Action & Adventure",
        10762: "Kids",
        10763: "News",
        10764: "Reality",
        10765: "Sci-Fi & Fantasy",
        10766: "Soap",
        10767: "Talk",
        10768: "War & Politics"
    ]
    
    public init(apiKey: String? = nil, readAccessToken: String? = nil) {
        if let apiKey { self.apiKey = apiKey }
        if let readAccessToken { self.readAccessToken = readAccessToken }
    }
    
    public func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    public func setReadAccessToken(_ token: String) {
        self.readAccessToken = token
    }
    
    // MARK: - ContentProvider Implementation
    
    public func fetchHeroSpotlights() async -> [MediaItem] {
        if let cached = memoryCache["hero_spotlights"], !cached.isEmpty {
            return cached
        }
        if let live = try? await getPagedMedia(endpoint: "/trending/all/day", type: .movie) {
            let candidates = live.filter { $0.backdropPath != nil && !$0.overview.isEmpty }
            if !candidates.isEmpty {
                var heroes = Array(candidates.prefix(8))
                for i in 0..<heroes.count {
                    heroes[i] = await enrichMediaItem(heroes[i])
                }
                memoryCache["hero_spotlights"] = heroes
                return heroes
            }
        }
        var fallback = Array((MockData.trendingItems + MockData.cinemaMovies).prefix(6))
        for i in 0..<fallback.count {
            fallback[i] = await enrichMediaItem(fallback[i])
        }
        memoryCache["hero_spotlights"] = fallback
        return fallback
    }
    
    public func fetchTrending(type: MediaType? = nil) async -> [MediaItem] {
        let cacheKey = "trending_\(type?.rawValue ?? "all")"
        if let cached = memoryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        let endpoint = type == nil ? "/trending/all/week" : "/trending/\(type!.rawValue)/week"
        if let items = try? await getPagedMedia(endpoint: endpoint, type: type ?? .movie), !items.isEmpty {
            memoryCache[cacheKey] = items
            return items
        }
        
        let items: [MediaItem]
        if let type {
            items = (MockData.trendingItems + MockData.cinemaMovies).filter { $0.mediaType == type }
        } else {
            items = MockData.trendingItems
        }
        memoryCache[cacheKey] = items
        return items
    }
    
    nonisolated public func isTheatricalExclusive(_ item: MediaItem) -> Bool {
        item.isTheatricalExclusive
    }
    
    public func fetchInCinemas() async -> [MediaItem] {
        if let cached = memoryCache["in_cinemas"], !cached.isEmpty {
            return cached
        }
        var verified: [MediaItem] = []
        if let items = try? await getPagedMedia(endpoint: "/movie/now_playing", type: .movie), !items.isEmpty {
            verified = await withTaskGroup(of: MediaItem?.self) { group in
                for item in items.prefix(25) {
                    group.addTask {
                        var m = item
                        let avail = await self.fetchWatchAvailability(id: m.id, mediaType: .movie, region: "US")
                        m.availability = avail
                        m.inCinemas = true
                        
                        // Strict check: zero digital release (no streaming, no rent, no buy)
                        guard m.isTheatricalExclusive else { return nil }
                        
                        // Must be currently playing (released on or before today)
                        guard m.isNowPlayingTheatrical else { return nil }
                        
                        return m
                    }
                }
                var list: [MediaItem] = []
                for await res in group {
                    if let res = res { list.append(res) }
                }
                return list
            }
        }
        var combined = verified
        var seenTitles = Set(verified.map { $0.title.lowercased() })
        for mock in MockData.cinemaMovies where mock.isNowPlayingTheatrical {
            if !seenTitles.contains(mock.title.lowercased()) {
                seenTitles.insert(mock.title.lowercased())
                var m = mock
                m.inCinemas = true
                combined.append(m)
            }
        }
        let sorted = combined.sorted { ($0.releaseDateString ?? "") > ($1.releaseDateString ?? "") }
        memoryCache["in_cinemas"] = sorted
        return sorted
    }
    
    public func fetchUpcomingCinemas() async -> [MediaItem] {
        if let cached = memoryCache["upcoming_cinemas"], !cached.isEmpty {
            return cached
        }
        var verified: [MediaItem] = []
        if let items = try? await getPagedMedia(endpoint: "/movie/upcoming", type: .movie), !items.isEmpty {
            verified = await withTaskGroup(of: MediaItem?.self) { group in
                for item in items.prefix(20) {
                    group.addTask {
                        var m = item
                        let avail = await self.fetchWatchAvailability(id: m.id, mediaType: .movie, region: "US")
                        m.availability = avail
                        m.inCinemas = false
                        
                        // Strict check: zero digital release
                        guard m.isTheatricalExclusive else { return nil }
                        
                        // Must be strictly upcoming (release date in future)
                        guard m.isUpcomingTheatrical else { return nil }
                        
                        return m
                    }
                }
                var list: [MediaItem] = []
                for await res in group {
                    if let res = res { list.append(res) }
                }
                return list
            }
        }
        var combined = verified
        var seenTitles = Set(verified.map { $0.title.lowercased() })
        for mock in MockData.upcoming where mock.isUpcomingTheatrical {
            if !seenTitles.contains(mock.title.lowercased()) {
                seenTitles.insert(mock.title.lowercased())
                var m = mock
                m.inCinemas = false
                combined.append(m)
            }
        }
        let sorted = combined.sorted { ($0.releaseDateString ?? "") < ($1.releaseDateString ?? "") }
        memoryCache["upcoming_cinemas"] = sorted
        return sorted
    }
    
    public func fetchStreaming(provider: StreamingProvider) async -> [MediaItem] {
        let cacheKey = "streaming_\(provider.id)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        
        async let moviesTask = try? getPagedMedia(
            endpoint: "/discover/movie?with_watch_providers=\(provider.id)&sort_by=popularity.desc",
            type: .movie
        )
        async let tvTask = try? getPagedMedia(
            endpoint: "/discover/tv?with_watch_providers=\(provider.id)&sort_by=popularity.desc",
            type: .tvShow
        )
        
        let movies = (await moviesTask) ?? []
        let tvShows = (await tvTask) ?? []
        
        var combined: [MediaItem] = []
        let maxCount = max(movies.count, tvShows.count)
        for i in 0..<maxCount {
            if i < movies.count { combined.append(movies[i]) }
            if i < tvShows.count { combined.append(tvShows[i]) }
        }
        
        if !combined.isEmpty {
            memoryCache[cacheKey] = combined
            return combined
        }
        
        let fallback = MockData.streamingCatalog[provider.id] ?? MockData.trendingItems
        memoryCache[cacheKey] = fallback
        return fallback
    }
    
    public func fetchPlatformTopMovies(provider: StreamingProvider) async -> [MediaItem] {
        let cacheKey = "platform_top_movies_\(provider.id)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        if let items = try? await getPagedMedia(
            endpoint: "/discover/movie?with_watch_providers=\(provider.id)&watch_region=GB&sort_by=popularity.desc",
            type: .movie
        ), !items.isEmpty {
            var rankedList: [MediaItem] = []
            for (idx, item) in items.prefix(10).enumerated() {
                var r = item
                r.rank = idx + 1
                rankedList.append(r)
            }
            memoryCache[cacheKey] = rankedList
            return rankedList
        }
        let catalog = MockData.streamingCatalog[provider.id] ?? []
        let raw = catalog.filter { $0.mediaType == .movie }
        let source = !raw.isEmpty ? raw : catalog
        var rankedList: [MediaItem] = []
        for (idx, item) in source.prefix(10).enumerated() {
            var r = item
            r.rank = idx + 1
            rankedList.append(r)
        }
        memoryCache[cacheKey] = rankedList
        return rankedList
    }
    
    public func fetchPlatformTopTV(provider: StreamingProvider) async -> [MediaItem] {
        let cacheKey = "platform_top_tv_\(provider.id)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        if let items = try? await getPagedMedia(
            endpoint: "/discover/tv?with_watch_providers=\(provider.id)&watch_region=GB&sort_by=popularity.desc",
            type: .tvShow
        ), !items.isEmpty {
            var rankedList: [MediaItem] = []
            for (idx, item) in items.prefix(10).enumerated() {
                var r = item
                r.rank = idx + 1
                rankedList.append(r)
            }
            memoryCache[cacheKey] = rankedList
            return rankedList
        }
        let catalog = MockData.streamingCatalog[provider.id] ?? []
        let raw = catalog.filter { $0.mediaType == .tvShow }
        let source = !raw.isEmpty ? raw : catalog
        var rankedList: [MediaItem] = []
        for (idx, item) in source.prefix(10).enumerated() {
            var r = item
            r.rank = idx + 1
            rankedList.append(r)
        }
        memoryCache[cacheKey] = rankedList
        return rankedList
    }
    
    public func fetchPlatformNew(provider: StreamingProvider) async -> [MediaItem] {
        let cacheKey = "platform_new_\(provider.id)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty {
            return cached
        }
        if let items = try? await getPagedMedia(
            endpoint: "/discover/movie?with_watch_providers=\(provider.id)&watch_region=GB&sort_by=primary_release_date.desc",
            type: .movie
        ), !items.isEmpty {
            memoryCache[cacheKey] = items
            return items
        }
        let catalog = MockData.streamingCatalog[provider.id] ?? []
        let fallback = Array(catalog.reversed().prefix(10))
        memoryCache[cacheKey] = fallback
        return fallback
    }
    
    public func fetchFreshFromTheatres() async -> [MediaItem] {
        if let cached = memoryCache["fresh_from_theatres"], !cached.isEmpty {
            return cached
        }
        let items = MockData.freshFromTheatres
        memoryCache["fresh_from_theatres"] = items
        return items
    }
    
    public func fetchMovies(category: String) async -> [MediaItem] {
        let cacheKey = "movies_\(category)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty { return cached }
        
        let endpoint: String
        switch category {
        case "top_rated": endpoint = "/movie/top_rated"
        case "now_playing": endpoint = "/movie/now_playing"
        case "upcoming": endpoint = "/movie/upcoming"
        default: endpoint = "/movie/popular"
        }
        
        if let items = try? await getPagedMedia(endpoint: endpoint, type: .movie), !items.isEmpty {
            memoryCache[cacheKey] = items
            return items
        }
        return (MockData.cinemaMovies + MockData.newReleases + MockData.topRated).filter { $0.mediaType == .movie }
    }
    
    public func fetchTVShows(category: String) async -> [MediaItem] {
        let cacheKey = "tv_\(category)"
        if let cached = memoryCache[cacheKey], !cached.isEmpty { return cached }
        
        let endpoint: String
        switch category {
        case "top_rated": endpoint = "/tv/top_rated"
        case "on_the_air": endpoint = "/tv/on_the_air"
        default: endpoint = "/tv/popular"
        }
        
        if let items = try? await getPagedMedia(endpoint: endpoint, type: .tvShow), !items.isEmpty {
            memoryCache[cacheKey] = items
            return items
        }
        return MockData.trendingItems.filter { $0.mediaType == .tvShow }
    }
    
    public func fetchWatchAvailability(id: Int, mediaType: MediaType, region: String = "US") async -> WatchAvailability {
        if let cached = availabilityCache[id] {
            return cached
        }
        
        let path = mediaType == .tvShow ? "/tv/\(id)/watch/providers" : "/movie/\(id)/watch/providers"
        if let url = URL(string: "\(baseURL)\(path)") {
            let request = createRequest(for: url)
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let decoded = try? JSONDecoder().decode(TMDBWatchProvidersResponse.self, from: data),
               let results = decoded.results {
                
                let candidateRegions = [region, "US", "GB", "CA", "AU", "DE", "FR"]
                var regionData: TMDBRegionProvidersDTO? = nil
                for r in candidateRegions {
                    if let found = results[r] {
                        regionData = found
                        break
                    }
                }
                if regionData == nil {
                    regionData = results.values.first
                }
                
                if let regionData = regionData {
                    var subs: [StreamingProvider] = []
                    var rent: [PurchaseOption] = []
                    var buy: [PurchaseOption] = []
                    
                    if let flatrate = regionData.flatrate {
                        for p in flatrate {
                            if let known = StreamingProvider.allGlobal.first(where: { $0.id == p.provider_id }) {
                                subs.append(known)
                            } else {
                                subs.append(StreamingProvider(id: p.provider_id, name: p.provider_name, logoPath: p.logo_path))
                            }
                        }
                    }
                    
                    if let rentList = regionData.rent {
                        for p in rentList {
                            rent.append(PurchaseOption(providerName: p.provider_name, price: "$3.99"))
                        }
                    }
                    
                    if let buyList = regionData.buy {
                        for p in buyList {
                            buy.append(PurchaseOption(providerName: p.provider_name, price: "$9.99"))
                        }
                    }
                    
                    let result = WatchAvailability(
                        subscriptions: subs,
                        rentOptions: rent,
                        buyOptions: buy,
                        cinemaStatus: mediaType == .movie ? "Now in Theatres" : nil,
                        attribution: "Streaming availability provided by JustWatch & TMDB"
                    )
                    availabilityCache[id] = result
                    return result
                } else {
                    // TMDB returned 200 with zero providers globally: theatrical exclusive or unreleased
                    let result = WatchAvailability(
                        subscriptions: [],
                        rentOptions: [],
                        buyOptions: [],
                        cinemaStatus: mediaType == .movie ? "Now in Theatres" : nil,
                        attribution: "Theatrical release data provided by JustWatch & TMDB"
                    )
                    availabilityCache[id] = result
                    return result
                }
            }
        }
        
        return fallbackMockAvailability(id: id)
    }
    
    public func fetchCredits(id: Int, mediaType: MediaType) async -> [CastMember] {
        if let cached = creditsCache[id] { return cached }
        let path = mediaType == .tvShow ? "/tv/\(id)/credits" : "/movie/\(id)/credits"
        guard let url = URL(string: "\(baseURL)\(path)") else { return [] }
        let request = createRequest(for: url)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(TMDBCreditsResponse.self, from: data),
              let cast = decoded.cast else {
            return []
        }
        let result = cast.prefix(12).map {
            CastMember(id: $0.id, name: $0.name, character: $0.character ?? "Cast", profilePath: $0.profile_path)
        }
        creditsCache[id] = result
        return result
    }
    
    public func fetchVideos(id: Int, mediaType: MediaType) async -> [VideoTrailer] {
        if let cached = videosCache[id] { return cached }
        let path = mediaType == .tvShow ? "/tv/\(id)/videos" : "/movie/\(id)/videos"
        guard let url = URL(string: "\(baseURL)\(path)") else { return [] }
        let request = createRequest(for: url)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let decoded = try? JSONDecoder().decode(TMDBVideosResponse.self, from: data),
              let videos = decoded.results else {
            return []
        }
        let trailers = videos.filter { $0.site == "YouTube" && ($0.type == "Trailer" || $0.type == "Teaser") }
        let selected = trailers.isEmpty ? videos.filter { $0.site == "YouTube" } : trailers
        let result = selected.prefix(4).map {
            VideoTrailer(id: $0.id, name: $0.name, key: $0.key, site: $0.site, type: $0.type)
        }
        videosCache[id] = result
        return result
    }
    
    public func fetchRecommendations(id: Int, mediaType: MediaType) async -> [MediaItem] {
        let path = mediaType == .tvShow ? "/tv/\(id)/recommendations" : "/movie/\(id)/recommendations"
        return (try? await getPagedMedia(endpoint: path, type: mediaType)) ?? []
    }
    
    public func fetchSeasons(tvShowId: Int) async -> [TVSeason] {
        if let cached = seasonsCache[tvShowId], !cached.isEmpty { return cached }
        guard let url = URL(string: "\(baseURL)/tv/\(tvShowId)") else { return [] }
        let request = createRequest(for: url)
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let decoded = try? JSONDecoder().decode(TMDBTVShowDetailsResponse.self, from: data),
           let seasons = decoded.seasons, !seasons.isEmpty {
            let list = seasons.map {
                TVSeason(
                    id: $0.id,
                    seasonNumber: $0.season_number,
                    name: $0.name,
                    episodeCount: $0.episode_count ?? 8,
                    posterPath: $0.poster_path
                )
            }
            seasonsCache[tvShowId] = list
            return list
        }
        
        let fallback = [
            TVSeason(id: tvShowId * 10 + 1, seasonNumber: 1, name: "Season 1", episodeCount: 8),
            TVSeason(id: tvShowId * 10 + 2, seasonNumber: 2, name: "Season 2", episodeCount: 8)
        ]
        seasonsCache[tvShowId] = fallback
        return fallback
    }
    
    public func fetchEpisodes(tvShowId: Int, seasonNumber: Int) async -> [TVEpisode] {
        let key = "\(tvShowId)_s\(seasonNumber)"
        if let cached = episodesCache[key], !cached.isEmpty { return cached }
        guard let url = URL(string: "\(baseURL)/tv/\(tvShowId)/season/\(seasonNumber)") else { return [] }
        let request = createRequest(for: url)
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let decoded = try? JSONDecoder().decode(TMDBSeasonDetailsResponse.self, from: data),
           let eps = decoded.episodes, !eps.isEmpty {
            let list = eps.map {
                TVEpisode(
                    id: $0.id,
                    episodeNumber: $0.episode_number,
                    seasonNumber: $0.season_number,
                    name: $0.name,
                    overview: $0.overview?.isEmpty == false ? $0.overview! : "No description available.",
                    runtime: $0.runtime ?? 48,
                    airDate: $0.air_date,
                    stillPath: $0.still_path
                )
            }
            episodesCache[key] = list
            return list
        }
        
        let fallback = (1...8).map { epNum in
            TVEpisode(
                id: tvShowId * 100 + epNum,
                episodeNumber: epNum,
                seasonNumber: seasonNumber,
                name: "Episode \(epNum)",
                overview: "Mark and his companions navigate shifting loyalties and high-stakes battles as new adversaries emerge.",
                runtime: 45 + (epNum * 4) % 15,
                airDate: "2024-03-\(epNum < 10 ? "0\(epNum)" : "\(epNum)")",
                stillPath: nil
            )
        }
        episodesCache[key] = fallback
        return fallback
    }
    
    public func search(query: String) async -> [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let items = try? await getPagedMedia(endpoint: "/search/multi?query=\(encoded)", type: .movie), !items.isEmpty {
            return items
        }
        
        let q = query.lowercased()
        let all = MockData.cinemaMovies + MockData.trendingItems + MockData.newReleases + MockData.topRated + MockData.upcoming
        var seen = Set<Int>()
        var results = [MediaItem]()
        for item in all {
            if !seen.contains(item.id) {
                let matchesTitle = item.title.lowercased().contains(q)
                let matchesGenre = item.genreNames.contains(where: { $0.lowercased().contains(q) })
                let matchesCast = item.cast.contains(where: { $0.name.lowercased().contains(q) || $0.character.lowercased().contains(q) })
                let matchesOverview = item.overview.lowercased().contains(q)
                if matchesTitle || matchesGenre || matchesCast || matchesOverview {
                    seen.insert(item.id)
                    results.append(item)
                }
            }
        }
        if results.isEmpty {
            for item in all {
                if !seen.contains(item.id) {
                    seen.insert(item.id)
                    results.append(item)
                    if results.count >= 8 { break }
                }
            }
        }
        return results
    }
    
    public func fetchNewReleases() async -> [MediaItem] {
        await fetchMovies(category: "popular")
    }
    
    public func fetchTopRated() async -> [MediaItem] {
        await fetchMovies(category: "top_rated")
    }
    
    public func fetchUpcoming() async -> [MediaItem] {
        await fetchUpcomingCinemas()
    }
    
    public func fetchCinemaMovies() async -> [MediaItem] {
        await fetchInCinemas()
    }
    
    public func fetchLogo(for item: MediaItem) async -> String? {
        if let cached = logoCache[item.id] {
            return cached
        }
        if item.title.localizedCaseInsensitiveContains("The Odyssey") || item.id == 1368337 || item.id == 1698863 {
            logoCache[item.id] = "/m6w20NsuOQN8dOM8DztHEvIALFd.png"
            return "/m6w20NsuOQN8dOM8DztHEvIALFd.png"
        }
        let endpoint = item.mediaType == .tvShow ? "/tv/\(item.id)/images" : "/movie/\(item.id)/images"
        guard let url = URL(string: "\(baseURL)\(endpoint)?api_key=\(apiKey)&include_image_language=en,null") else {
            return nil
        }
        let request = createRequest(for: url)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(TMDBImagesResponse.self, from: data) else {
            return nil
        }
        let logo = decoded.logos?.first(where: { $0.iso_639_1 == "en" }) ?? decoded.logos?.first
        if let path = logo?.file_path {
            logoCache[item.id] = path
            return path
        }
        return nil
    }
    
    public func enrichMediaItem(_ item: MediaItem) async -> MediaItem {
        if let cached = enrichedCache[item.id] {
            return cached
        }
        
        if item.title.localizedCaseInsensitiveContains("The Odyssey") || item.id == 1368337 || item.id == 1698863 {
            var ody = item
            ody.logoPath = "/m6w20NsuOQN8dOM8DztHEvIALFd.png"
            enrichedCache[item.id] = ody
            return ody
        }
        
        if item.runtimeMinutes != nil && item.certification != nil && item.logoPath != nil {
            enrichedCache[item.id] = item
            return item
        }
        
        var enriched = item
        let isTV = (item.mediaType == .tvShow)
        let append = isTV ? "content_ratings,images" : "release_dates,images"
        let endpoint = isTV ? "/tv/\(item.id)?append_to_response=\(append)" : "/movie/\(item.id)?append_to_response=\(append)"
        let separator = endpoint.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(baseURL)\(endpoint)\(separator)api_key=\(apiKey)") else {
            enrichedCache[item.id] = item
            return item
        }
        
        let request = createRequest(for: url)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            enrichedCache[item.id] = item
            return item
        }
        
        // Runtime
        if enriched.runtimeMinutes == nil || enriched.runtimeMinutes == 0 {
            if let r = json["runtime"] as? Int, r > 0 {
                enriched.runtimeMinutes = r
            } else if let epRun = json["episode_run_time"] as? [Int], let first = epRun.first, first > 0 {
                enriched.runtimeMinutes = first
            }
        }
        
        // Certification
        if enriched.certification == nil || enriched.certification?.isEmpty == true {
            var cert: String? = nil
            if !isTV {
                if let relDates = json["release_dates"] as? [String: Any],
                   let results = relDates["results"] as? [[String: Any]] {
                    for res in results {
                        let iso = res["iso_3166_1"] as? String
                        if iso == "US" || iso == "GB" {
                            if let dates = res["release_dates"] as? [[String: Any]] {
                                for d in dates {
                                    if let c = d["certification"] as? String, !c.isEmpty {
                                        cert = c
                                        break
                                    }
                                }
                            }
                        }
                        if cert != nil { break }
                    }
                }
            } else {
                if let contentRatings = json["content_ratings"] as? [String: Any],
                   let results = contentRatings["results"] as? [[String: Any]] {
                    for res in results {
                        let iso = res["iso_3166_1"] as? String
                        if iso == "US" || iso == "GB" {
                            if let r = res["rating"] as? String, !r.isEmpty {
                                cert = r
                                break
                            }
                        }
                    }
                }
            }
            if let cert {
                enriched.certification = cert
            }
        }
        
        // Tagline
        if enriched.tagline == nil || enriched.tagline?.isEmpty == true {
            if let tag = json["tagline"] as? String, !tag.isEmpty {
                enriched.tagline = tag
            }
        }
        
        // Logo
        if enriched.logoPath == nil || enriched.logoPath?.isEmpty == true {
            if let images = json["images"] as? [String: Any],
               let logos = images["logos"] as? [[String: Any]] {
                let enLogo = logos.first(where: { ($0["iso_639_1"] as? String) == "en" }) ?? logos.first
                if let path = enLogo?["file_path"] as? String {
                    enriched.logoPath = path
                }
            }
        }
        
        enrichedCache[item.id] = enriched
        return enriched
    }
    
    // MARK: - Network Request Helper
    
    private func createRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(readAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        return request
    }
    
    private func getPagedMedia(endpoint: String, type: MediaType) async throws -> [MediaItem] {
        let separator = endpoint.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(baseURL)\(endpoint)\(separator)api_key=\(apiKey)") else { return [] }
        
        let request = createRequest(for: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let decoded = try JSONDecoder().decode(TMDBPagedResponse.self, from: data)
        return decoded.results.compactMap { dto in
            guard let id = dto.id else { return nil }
            if dto.media_type == "person" { return nil }
            guard dto.poster_path != nil || dto.backdrop_path != nil else { return nil }
            let detectedType = dto.media_type == "tv" ? MediaType.tvShow : (dto.media_type == "movie" ? MediaType.movie : type)
            let rawTitle = dto.title ?? dto.name ?? dto.original_title ?? dto.original_name
            guard let title = rawTitle, !title.isEmpty else { return nil }
            
            let genreNames = (dto.genre_ids ?? []).compactMap { Self.genreMap[$0] }
            
            let isOdyssey = title.localizedCaseInsensitiveContains("The Odyssey") || id == 1368337 || id == 1698863
            let finalPoster = isOdyssey ? "/b0z3ViIC5AkbJoqxmTpqyjgmoJs.jpg" : dto.poster_path
            let finalBackdrop = isOdyssey ? "/mPy1xSASQ9NYWJdAGx2C2sOsnNw.jpg" : dto.backdrop_path
            let finalLogo = isOdyssey ? "/m6w20NsuOQN8dOM8DztHEvIALFd.png" : nil

            return MediaItem(
                id: isOdyssey ? 1698863 : id,
                title: title,
                originalTitle: dto.original_title ?? dto.original_name,
                mediaType: detectedType,
                overview: dto.overview ?? "",
                posterPath: finalPoster,
                backdropPath: finalBackdrop,
                voteAverage: dto.vote_average ?? 0.0,
                voteCount: dto.vote_count ?? 0,
                releaseDateString: dto.release_date ?? dto.first_air_date,
                genreNames: genreNames,
                runtimeMinutes: dto.runtime ?? dto.episode_run_time?.first,
                tagline: dto.tagline
            )
        }
    }
    
    private func fallbackMockAvailability(id: Int) -> WatchAvailability {
        var subs: [StreamingProvider] = []
        var rent: [PurchaseOption] = []
        var buy: [PurchaseOption] = []
        var cinemaStatus: String? = nil
        
        switch id {
        case 201, 202:
            subs = [.appleTV]
        case 203:
            subs = [.max, .primeVideo]
            rent = [PurchaseOption(providerName: "Apple TV", price: "$3.99")]
            buy = [PurchaseOption(providerName: "Apple TV", price: "$14.99")]
        case 204:
            subs = [.disneyPlus]
        case 101:
            subs = [.max, .primeVideo]
            rent = [PurchaseOption(providerName: "Apple TV", price: "$3.99"), PurchaseOption(providerName: "Prime Video", price: "$3.99")]
            buy = [PurchaseOption(providerName: "Apple TV", price: "$14.99")]
            cinemaStatus = "Now in Theatres"
        case 102:
            subs = [.paramountPlus, .primeVideo]
            rent = [PurchaseOption(providerName: "Apple TV", price: "$3.99")]
            buy = [PurchaseOption(providerName: "Apple TV", price: "$9.99")]
        default:
            subs = []
            rent = []
            buy = []
        }
        
        return WatchAvailability(
            subscriptions: subs,
            rentOptions: rent,
            buyOptions: buy,
            cinemaStatus: cinemaStatus,
            attribution: "Streaming data provided by JustWatch & TMDB"
        )
    }
}

// MARK: - DTO Decoders

private struct TMDBPagedResponse: Codable {
    let page: Int?
    let results: [TMDBMediaDTO]
}

private struct TMDBMediaDTO: Codable {
    let id: Int?
    let title: String?
    let name: String?
    let original_title: String?
    let original_name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let vote_average: Double?
    let vote_count: Int?
    let release_date: String?
    let first_air_date: String?
    let media_type: String?
    let genre_ids: [Int]?
    let runtime: Int?
    let episode_run_time: [Int]?
    let tagline: String?
}

private struct TMDBCreditsResponse: Codable {
    let cast: [TMDBCastDTO]?
}

private struct TMDBCastDTO: Codable {
    let id: Int
    let name: String
    let character: String?
    let profile_path: String?
}

private struct TMDBVideosResponse: Codable {
    let results: [TMDBVideoDTO]?
}

private struct TMDBVideoDTO: Codable {
    let id: String
    let name: String
    let key: String
    let site: String
    let type: String
}

private struct TMDBWatchProvidersResponse: Codable {
    let results: [String: TMDBRegionProvidersDTO]?
}

private struct TMDBRegionProvidersDTO: Codable {
    let link: String?
    let flatrate: [TMDBProviderDTO]?
    let rent: [TMDBProviderDTO]?
    let buy: [TMDBProviderDTO]?
}

private struct TMDBProviderDTO: Codable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
}

private struct TMDBTVShowDetailsResponse: Codable {
    let seasons: [TMDBSeasonDTO]?
}

private struct TMDBSeasonDTO: Codable {
    let id: Int
    let season_number: Int
    let name: String
    let episode_count: Int?
    let poster_path: String?
}

private struct TMDBSeasonDetailsResponse: Codable {
    let episodes: [TMDBEpisodeDTO]?
}

private struct TMDBEpisodeDTO: Codable {
    let id: Int
    let episode_number: Int
    let season_number: Int
    let name: String
    let overview: String?
    let runtime: Int?
    let air_date: String?
    let still_path: String?
}

private struct TMDBImagesResponse: Codable {
    let id: Int?
    let logos: [TMDBLogoDTO]?
}

private struct TMDBLogoDTO: Codable {
    let aspect_ratio: Double?
    let file_path: String?
    let iso_639_1: String?
    let vote_average: Double?
}

// MARK: - Rich Curated Mock Data (Zero Emojis)

public enum MockData {
    public static let cinemaMovies: [MediaItem] = [
        MediaItem(
            id: 969681,
            title: "Spider-Man: Brand New Day",
            mediaType: .movie,
            overview: "Peter Parker navigates life completely on his own in New York City while facing a new syndicate of criminals threatening the borough.",
            posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
            backdropPath: "/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg",
            voteAverage: 8.4,
            voteCount: 1820,
            releaseDateString: "2026-07-29",
            genreNames: ["Action", "Adventure", "Sci-Fi"],
            runtimeMinutes: 135,
            tagline: "A clean slate in a dangerous city.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "sp1", name: "Theatrical Trailer", key: "x0XDEhP4MQs")],
            cast: [
                CastMember(id: 1136406, name: "Tom Holland", character: "Peter Parker / Spider-Man"),
                CastMember(id: 505710, name: "Zendaya", character: "MJ")
            ],
            logoPath: "/vbZcDHC5IFylYuRnp3eyOs5rTV1.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1302904,
            title: "Practical Magic 2",
            mediaType: .movie,
            overview: "The Owens sisters reunite as an unexpected ancestral hex emerges, forcing them to protect their family and delve into ancient enchantments.",
            posterPath: "/ogwQOLbCfncjvBhFb5l0OmQH8KC.jpg",
            backdropPath: "/nUcauJ000dFBYkgGpxyxJ5aWEH2.jpg",
            voteAverage: 8.0,
            voteCount: 920,
            releaseDateString: "2026-09-11",
            genreNames: ["Comedy", "Fantasy", "Drama"],
            runtimeMinutes: 118,
            tagline: "There's a little witch in all of us.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "pm2_1", name: "Official Trailer", key: "d9MyW72ELq0")],
            cast: [
                CastMember(id: 18277, name: "Sandra Bullock", character: "Sally Owens"),
                CastMember(id: 2227, name: "Nicole Kidman", character: "Gillian Owens")
            ],
            logoPath: "/kK7hIYNupIRjP6cYKN2P2gzYHLU.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1204680,
            title: "Coyote vs. Acme",
            mediaType: .movie,
            overview: "After ACME products fail him one too many times in his pursuit of the Road Runner, Wile E. Coyote hires a human attorney to sue the conglomerate.",
            posterPath: "/orkLtdgMGiO9rTVMqJ1kKwrnup1.jpg",
            backdropPath: "/l9mFW9HQnAZ4r1ChZJHoOT3jaal.jpg",
            voteAverage: 8.1,
            voteCount: 1450,
            releaseDateString: "2026-08-20",
            genreNames: ["Comedy", "Family", "Animation"],
            runtimeMinutes: 98,
            tagline: "Justice will be beep-beeped.",
            certification: "PG",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "cva1", name: "Official Trailer", key: "As-vKW4ZboI")],
            cast: [
                CastMember(id: 12109, name: "Will Forte", character: "Kevin Avery"),
                CastMember(id: 56446, name: "John Cena", character: "ACME Counsel"),
                CastMember(id: 13184, name: "Lana Condor", character: "Paige")
            ],
            logoPath: "/3m1raTve2RWZ0jfnUwHSnRtjVK3.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1698863,
            title: "The Odyssey",
            mediaType: .movie,
            overview: "Based on the Ancient Greek epic. After ten years of war, King Odysseus sets sail for Ithaca, eager to reunite with his beloved. But his journey home is far more treacherous than the battlefield, as he must face deadly monsters and vengeful gods to survive.",
            posterPath: "/b0z3ViIC5AkbJoqxmTpqyjgmoJs.jpg",
            backdropPath: "/mPy1xSASQ9NYWJdAGx2C2sOsnNw.jpg",
            voteAverage: 8.3,
            voteCount: 1280,
            releaseDateString: "2026-07-03",
            genreNames: ["Adventure", "Fantasy", "Action"],
            runtimeMinutes: 165,
            tagline: "The voyage that defined eternity.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "od1", name: "Cinematic Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 1892, name: "Matt Damon", character: "Odysseus"),
                CastMember(id: 3456, name: "Charlize Theron", character: "Penelope")
            ],
            logoPath: "/m6w20NsuOQN8dOM8DztHEvIALFd.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1101412,
            title: "Fall 2: Deadpoint",
            mediaType: .movie,
            overview: "Two technical mountaineers find themselves stranded on an isolated sheer mountain needle in the Swiss Alps after a cable car collapses.",
            posterPath: "/fgSm5ylwiXbIHn8UbUXDjk9RRu4.jpg",
            backdropPath: "/yQXU4rgJ5LVCzn16SeIg34T35lV.jpg",
            voteAverage: 7.5,
            voteCount: 890,
            releaseDateString: "2026-09-09",
            genreNames: ["Thriller", "Action"],
            runtimeMinutes: 104,
            tagline: "Nowhere to go but down.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "f2_1", name: "Official Trailer", key: "Way9Dexny3w")],
            cast: [
                CastMember(id: 3012, name: "Grace Caroline Currey", character: "Becky Connor"),
                CastMember(id: 4015, name: "Virginia Gardner", character: "Hunter")
            ],
            logoPath: "/zoJEVzPC6DLHQ5KzoyDQ5357B2z.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1318413,
            title: "Pressure",
            mediaType: .movie,
            overview: "During the tense 72 hours leading up to D-Day, Britain's chief meteorological officer must make the most consequential weather forecast in history.",
            posterPath: "/gFjEggtrejCN79r6SXRjM269OtG.jpg",
            backdropPath: "/apfyLCPVFttB8oXcsLJ7q0NSFLx.jpg",
            voteAverage: 8.2,
            voteCount: 780,
            releaseDateString: "2026-09-09",
            genreNames: ["Drama", "War", "History"],
            runtimeMinutes: 112,
            tagline: "One decision would change the war.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "pr1", name: "Official Trailer", key: "73_1biulkYk")],
            cast: [
                CastMember(id: 5432, name: "Andrew Scott", character: "James Stagg"),
                CastMember(id: 1987, name: "Brendan Fraser", character: "Gen. Dwight D. Eisenhower")
            ],
            logoPath: "/A28r04yW2BQgEniLt5inopfryWE.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1284046,
            title: "Onslaught",
            mediaType: .movie,
            overview: "A mother living in an isolated wilderness homestead must use her clandestine former training to defend her family against a mercenary squad.",
            posterPath: "/cOGtvhc6Ij9KvzM6jZsfQyg0B0O.jpg",
            backdropPath: "/pmPXXniQlb4EdYY0gVZO90rf54F.jpg",
            voteAverage: 7.8,
            voteCount: 650,
            releaseDateString: "2026-09-02",
            genreNames: ["Action", "Thriller"],
            runtimeMinutes: 108,
            tagline: "They brought the fight to the wrong home.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "on1", name: "Red Band Trailer", key: "x0XDEhP4MQs")],
            cast: [
                CastMember(id: 6789, name: "Adria Arjona", character: "Valeria"),
                CastMember(id: 9812, name: "Dan Stevens", character: "Lead Mercenary")
            ],
            logoPath: "/bDjcbJZL2JpBuyab36UZzpEMTGO.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1288445,
            title: "Mutiny",
            mediaType: .movie,
            overview: "After his billionaire industrialist boss is murdered in front of him, an elite operative is framed for the crime, embarking on a relentless cross-continent chase to expose an international conspiracy.",
            posterPath: "/pu2VxGlpGwffOx292w18b1tv96j.jpg",
            backdropPath: "/e2QAGrEmbpmZpMymDRkDisJkvg9.jpg",
            voteAverage: 7.7,
            voteCount: 590,
            releaseDateString: "2026-09-04",
            genreNames: ["Action", "Thriller", "Crime"],
            runtimeMinutes: 122,
            tagline: "Survival has no rules.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "bam1", name: "Official Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 976, name: "Jason Statham", character: "Cole Reed"),
                CastMember(id: 3896, name: "Annabelle Wallis", character: "Tara")
            ],
            logoPath: "/1fBG0oBuRyPq5omo7H4DlvC66Aq.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1198654,
            title: "Bad Apples",
            mediaType: .movie,
            overview: "A devoted primary school teacher struggles with an unruly, disruptive ten-year-old student until a bizarre series of misadventures spirals out of control.",
            posterPath: "/60BxAjKM20ABTSYnWZcJ8ExiVNL.jpg",
            backdropPath: "/A5sGEzVMjvbgh5ZniaHBXAxppKQ.jpg",
            voteAverage: 8.0,
            voteCount: 710,
            releaseDateString: "2026-09-05",
            genreNames: ["Comedy", "Thriller"],
            runtimeMinutes: 105,
            tagline: "One bad apple spoils the bunch.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "ba1", name: "Official Trailer", key: "Way9Dexny3w")],
            cast: [
                CastMember(id: 3412, name: "Saoirse Ronan", character: "Maria"),
                CastMember(id: 7654, name: "Jacob Tremblay", character: "Robert")
            ],
            logoPath: "/y1OzxvuQihyf1DZHU6Pb5cUjENO.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1377237,
            title: "Runner",
            mediaType: .movie,
            overview: "A high-stakes courier in a fortified metropolis is tasked with transporting an organ transplant across enemy territory under an absolute deadline.",
            posterPath: "/yBKMAIj7clP42UkFejhGDBBoTpb.jpg",
            backdropPath: "/iXR79oKsLHwLno9jdzxxeFP21sy.jpg",
            voteAverage: 7.9,
            voteCount: 680,
            releaseDateString: "2026-09-07",
            genreNames: ["Action", "Thriller"],
            runtimeMinutes: 114,
            tagline: "Stop running. Start fighting.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "rn1", name: "Trailer", key: "6COmYeLsz4c")],
            cast: [
                CastMember(id: 5412, name: "Alan Ritchson", character: "Hank"),
                CastMember(id: 9021, name: "Eiza González", character: "Dr. Scott")
            ],
            logoPath: "/fFjGsyHwSUMkOsYCuXgzUbLIJoZ.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1375646,
            title: "Colony",
            mediaType: .movie,
            overview: "A deep-space colonization vessel discovers an uncharted biosphere harboring an ancient architecture that awakens upon their landing.",
            posterPath: "/tN799oUR0f1gUKDYdMNrDaY7I51.jpg",
            backdropPath: "/hpBGCnzOvdtQoMyE48gvwp2y5yx.jpg",
            voteAverage: 7.9,
            voteCount: 1120,
            releaseDateString: "2026-05-21",
            genreNames: ["Sci-Fi", "Thriller", "Mystery"],
            runtimeMinutes: 132,
            tagline: "We were not the first.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "col1", name: "Teaser", key: "73_1biulkYk")],
            cast: [
                CastMember(id: 819, name: "Edward Norton", character: "Commander Vance"),
                CastMember(id: 923, name: "Rebecca Hall", character: "Dr. Catherine Shaw")
            ],
            logoPath: "/hCK5tVvTG2c0SrOaPCWMlbMj69A.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1393326,
            title: "Ghost in the Cell",
            mediaType: .movie,
            overview: "A locked-down high-tech bio-research facility experiences an artificial intelligence containment breach during a midnight storm.",
            posterPath: "/zxcMdx0w5Zmg8yZuuiS7CJ8vOea.jpg",
            backdropPath: "/tK3QdOOrX4qEkmSlvrmc8cK7iOU.jpg",
            voteAverage: 7.7,
            voteCount: 940,
            releaseDateString: "2026-04-16",
            genreNames: ["Horror", "Sci-Fi", "Action"],
            runtimeMinutes: 110,
            tagline: "Locked inside with the anomaly.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "gitc1", name: "Trailer", key: "67vbA5ZJb3k")],
            cast: [
                CastMember(id: 1980, name: "Dan Stevens", character: "Dr. Isaac Cole"),
                CastMember(id: 2450, name: "Maika Monroe", character: "Elena Rios")
            ],
            logoPath: "/pEzRWmKyXZYnqWQGisS8Q8CiXcb.png",
            inCinemas: true
        ),
        MediaItem(
            id: 977942,
            title: "The Uprising",
            mediaType: .movie,
            overview: "When a totalitarian regime disables planetary communications, a rebellion orchestrates a tactical resistance from the underground catacombs.",
            posterPath: "/7TUl15TOsIvndKlgMWTtLgtEzZP.jpg",
            backdropPath: "/4YyuSadBoc5k6krj0REcYH15DXG.jpg",
            voteAverage: 8.1,
            voteCount: 750,
            releaseDateString: "2026-09-11",
            genreNames: ["Action", "Sci-Fi", "Drama"],
            runtimeMinutes: 128,
            tagline: "Silence will be broken.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "up1", name: "Teaser", key: "As-vKW4ZboI")],
            cast: [
                CastMember(id: 3124, name: "John Boyega", character: "Kaelen"),
                CastMember(id: 6521, name: "Florence Pugh", character: "Sari")
            ],
            logoPath: "/drBOdj4htH0Chlno2Ctt6OxCGgJ.png",
            inCinemas: true
        ),
        MediaItem(
            id: 1228834,
            title: "The Fix",
            mediaType: .movie,
            overview: "A disgraced former surgeon must navigate the treacherous criminal underworld after agreeing to perform an illicit procedure on a cartel boss.",
            posterPath: "/yopXjun3ICFfJci2ukcEzceZjUs.jpg",
            backdropPath: "/dJTWIecL2vxsCRl5G0lRhPsfrhc.jpg",
            voteAverage: 7.6,
            voteCount: 520,
            releaseDateString: "2026-09-11",
            genreNames: ["Thriller", "Drama", "Crime"],
            runtimeMinutes: 106,
            tagline: "No mistakes. No second chances.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "fx1", name: "Official Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 2841, name: "Mads Mikkelsen", character: "Dr. Arthur Bell"),
                CastMember(id: 7129, name: "Ana de Armas", character: "Elena")
            ],
            logoPath: "/sg0cMIDL4dwMZEu2wPIFTUppquO.png",
            inCinemas: true
        )
    ]
    
    public static let freshFromTheatres: [MediaItem] = [
        MediaItem(
            id: 1228710,
            title: "Star Wars: The Mandalorian and Grogu",
            mediaType: .movie,
            overview: "The Mandalorian and his young apprentice Grogu embark on a feature-length cinematic adventure across the Outer Rim of the galaxy, defending allies against imperial remnants.",
            posterPath: "/fsSMj6TJ6qtMnpg6UIw8TzUeEyE.jpg",
            backdropPath: "/ysLlsAxwgNSxBWHCgTKJrmjxpRQ.jpg",
            voteAverage: 8.4,
            voteCount: 4200,
            releaseDateString: "2026-05-22",
            genreNames: ["Action", "Sci-Fi", "Adventure"],
            runtimeMinutes: 125,
            tagline: "This is the way.",
            certification: "PG-13",
            streamingProviders: [.disneyPlus, .appleTV, .primeVideo],
            trailers: [VideoTrailer(id: "mg1", name: "Official Trailer", key: "aDyQxtg0V2w")],
            cast: [
                CastMember(id: 1253360, name: "Pedro Pascal", character: "Din Djarin / The Mandalorian"),
                CastMember(id: 10182, name: "Sigourney Weaver", character: "Col. Ward")
            ],
            logoPath: "/xSj9QrjsR8fZnSuEt6e7QZvrqSy.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1386315,
            title: "The Runner",
            mediaType: .movie,
            overview: "A high-stakes psychological thriller following a prominent attorney whose daughter is held hostage by a syndicate demanding the retrieval of sensitive financial data.",
            posterPath: "/uxCaBoYXsDC4A0SqTm3SISj0OwK.jpg",
            backdropPath: "/pwIX6Qn9TG1XrBNGzZ7cjZ52Pa8.jpg",
            voteAverage: 7.9,
            voteCount: 1540,
            releaseDateString: "2026-09-02",
            genreNames: ["Thriller", "Drama", "Mystery"],
            runtimeMinutes: 115,
            tagline: "Every second counts.",
            certification: "R",
            streamingProviders: [.primeVideo, .appleTV],
            trailers: [VideoTrailer(id: "tr1", name: "Trailer", key: "x0XDEhP4MQs")],
            cast: [
                CastMember(id: 9021, name: "Gal Gadot", character: "Katherine"),
                CastMember(id: 4120, name: "Woody Harrelson", character: "Mason")
            ],
            logoPath: "/At3Av06KDQ4GwIKSAh1dnG8wz7G.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1137844,
            title: "Mayday",
            mediaType: .movie,
            overview: "A charismatic commercial airline pilot and a stoic air marshal must work together when their transatlantic flight is intercepted over the Arctic Circle.",
            posterPath: "/hVXjX1jLZ1ljFSNGXpjJfbTUOa7.jpg",
            backdropPath: "/4gyx49ibwQslyrwuUS1c58PJEEd.jpg",
            voteAverage: 8.1,
            voteCount: 1820,
            releaseDateString: "2026-09-04",
            genreNames: ["Action", "Comedy", "Adventure"],
            runtimeMinutes: 118,
            tagline: "Cleared for chaos.",
            certification: "PG-13",
            streamingProviders: [.appleTV, .primeVideo],
            trailers: [VideoTrailer(id: "md1", name: "Official Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 47, name: "Ryan Reynolds", character: "Captain Troy"),
                CastMember(id: 3120, name: "Kenneth Branagh", character: "Commander Ross")
            ],
            logoPath: "/o7u1JJCrdSoWnNmaoLdEBOBfYG6.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1522689,
            title: "Why Did I Get Married Again?",
            mediaType: .movie,
            overview: "Eight married friends reunite for an annual retreat in the Bahamas, only to confront surprising secrets, shifting loyalties, and unexpected life turns.",
            posterPath: "/bHMtdZFZztcAE5uHHhsY2pWRPB9.jpg",
            backdropPath: "/lJYniNRM2i9wXnfWVHOB4PxygFZ.jpg",
            voteAverage: 7.5,
            voteCount: 980,
            releaseDateString: "2026-09-09",
            genreNames: ["Comedy", "Drama", "Romance"],
            runtimeMinutes: 122,
            tagline: "Marriage takes work.",
            certification: "PG-13",
            streamingProviders: [.netflix],
            trailers: [VideoTrailer(id: "wd1", name: "Trailer", key: "6COmYeLsz4c")],
            cast: [
                CastMember(id: 5410, name: "Tyler Perry", character: "Terry"),
                CastMember(id: 6120, name: "Janet Jackson", character: "Patricia")
            ],
            logoPath: "/opsE1rUAgCy29Bdv6EbXnP1e5PO.png",
            inCinemas: false
        ),
        MediaItem(
            id: 687163,
            title: "Project Hail Mary",
            mediaType: .movie,
            overview: "Lone astronaut Ryland Grace wakes up aboard a spacecraft with amnesia, slowly discovering he is humanity's last hope to solve an extinction-level solar crisis.",
            posterPath: "/yihdXomYb5kTeSivtFndMy5iDmf.jpg",
            backdropPath: "/wLWvHcQz7N13DvSOTV7bHgwGXpT.jpg",
            voteAverage: 8.7,
            voteCount: 5120,
            releaseDateString: "2026-07-18",
            genreNames: ["Sci-Fi", "Adventure", "Drama"],
            runtimeMinutes: 148,
            tagline: "Earth has one chance. He is it.",
            certification: "PG-13",
            streamingProviders: [.primeVideo, .appleTV],
            trailers: [VideoTrailer(id: "phm1", name: "Official Trailer", key: "Way9Dexny3w")],
            cast: [
                CastMember(id: 30614, name: "Ryan Gosling", character: "Ryland Grace"),
                CastMember(id: 11090, name: "Sandra Hüller", character: "Eva Stratt")
            ],
            logoPath: "/jvqIELbZctv3Jqtcc7Ic5of8vY7.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1202033,
            title: "Enola Holmes 3",
            mediaType: .movie,
            overview: "Enola Holmes uncovers a conspiracy reaching into the heart of London's royal societies while collaborating with her brother Sherlock on a baffling case.",
            posterPath: "/7kRYHH9H9PjBFwz1FprbHB2AAjI.jpg",
            backdropPath: "/jLuGZc84MvPYCQomQg9DI72mstt.jpg",
            voteAverage: 7.9,
            voteCount: 3200,
            releaseDateString: "2026-07-01",
            genreNames: ["Mystery", "Adventure", "Crime"],
            runtimeMinutes: 128,
            tagline: "The game finds a new master.",
            certification: "PG-13",
            streamingProviders: [.netflix],
            trailers: [VideoTrailer(id: "eh3_1", name: "Trailer", key: "73_1biulkYk")],
            cast: [
                CastMember(id: 1356210, name: "Millie Bobby Brown", character: "Enola Holmes"),
                CastMember(id: 73968, name: "Henry Cavill", character: "Sherlock Holmes")
            ],
            logoPath: "/pVeJDWwmgXID7Bs8u0d21pr55Oj.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1266127,
            title: "Ready or Not 2: Here I Come",
            mediaType: .movie,
            overview: "Grace thought the Le Domas ritual was behind her until an international branch of high-society elites initiates a new deadly game of survival.",
            posterPath: "/13ZcJzSGEqVgDSqsS9U5EkQwPkV.jpg",
            backdropPath: "/fx2cEuadZK28VHKkc0F1nFR96i0.jpg",
            voteAverage: 7.8,
            voteCount: 2450,
            releaseDateString: "2026-07-02",
            genreNames: ["Horror", "Comedy", "Thriller"],
            runtimeMinutes: 104,
            tagline: "New rules. Same bride.",
            certification: "R",
            streamingProviders: [.disneyPlus, .appleTV],
            trailers: [VideoTrailer(id: "ron2_1", name: "Red Band Trailer", key: "x0XDEhP4MQs")],
            cast: [
                CastMember(id: 1150450, name: "Samara Weaving", character: "Grace"),
                CastMember(id: 54109, name: "Kathryn Newton", character: "Beatrice")
            ],
            logoPath: "/4GoX0K6uv0u7YkR1O27CHpyquqS.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1007757,
            title: "Swapped",
            mediaType: .movie,
            overview: "In a futuristic society where minds can be temporarily swapped for occupational training, two polar-opposite rivals get trapped in each other's lives.",
            posterPath: "/tHhxWxge06goXU6ZQH1hj7vK8Hd.jpg",
            backdropPath: "/zMwhWailP1WY7sb6AoE6b8ugoy.jpg",
            voteAverage: 7.7,
            voteCount: 1980,
            releaseDateString: "2026-06-25",
            genreNames: ["Animation", "Comedy", "Sci-Fi"],
            runtimeMinutes: 98,
            tagline: "Walk a mile in someone else's neural link.",
            certification: "PG",
            streamingProviders: [.netflix],
            trailers: [VideoTrailer(id: "sw1", name: "Trailer", key: "As-vKW4ZboI")],
            cast: [
                CastMember(id: 135651, name: "Michael B. Jordan", character: "Leo (voice)"),
                CastMember(id: 21094, name: "Juno Temple", character: "Maya (voice)")
            ],
            logoPath: "/gEnzsqzZPHITrRd3KupXbh2KCpY.png",
            inCinemas: false
        ),
        MediaItem(
            id: 949838,
            title: "72 Hours",
            mediaType: .movie,
            overview: "A chaotic weekend road trip turns into an adrenaline-fueled dash across the city when two brothers get mixed up with stolen contraband.",
            posterPath: "/9Bu1PW2R1XayqRqnl0aDOgMcrdS.jpg",
            backdropPath: "/2vAmfcW5GSmIXPnRt1SKBx6dEv6.jpg",
            voteAverage: 7.4,
            voteCount: 1620,
            releaseDateString: "2026-08-14",
            genreNames: ["Comedy", "Action"],
            runtimeMinutes: 102,
            tagline: "Sunshine, palm trees, and bad decisions.",
            certification: "R",
            streamingProviders: [.netflix],
            trailers: [VideoTrailer(id: "72h1", name: "Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 55638, name: "Kevin Hart", character: "Marcus"),
                CastMember(id: 62849, name: "Marlon Wayans", character: "Dre")
            ],
            logoPath: "/dstq6iwyesaD9Hx4SC8nQOYhJEl.png",
            inCinemas: false
        )
    ]
    
    public static let trendingItems: [MediaItem] = [
        MediaItem(
            id: 95396,
            title: "Severance",
            mediaType: .tvShow,
            overview: "Mark leads a team of office workers whose memories have been surgically divided between their work and personal lives. When a mysterious colleague appears outside of work, it begins a journey to discover the truth about their jobs.",
            posterPath: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg",
            backdropPath: "/ixgFmf1X59PUZam2qbAfskx2gQr.jpg",
            voteAverage: 8.7,
            voteCount: 3900,
            releaseDateString: "2022-02-18",
            genreNames: ["Sci-Fi", "Mystery", "Drama"],
            runtimeMinutes: 55,
            tagline: "Please do not attempt to adjust your focus.",
            certification: "TV-MA",
            streamingProviders: [.appleTV],
            trailers: [VideoTrailer(id: "t5", name: "Season 2 Teaser", key: "xEQP4VVuyrY")],
            cast: [
                CastMember(id: 14, name: "Adam Scott", character: "Mark Scout"),
                CastMember(id: 15, name: "Patricia Arquette", character: "Harmony Cobel"),
                CastMember(id: 16, name: "John Turturro", character: "Irving")
            ]
        ),
        MediaItem(
            id: 95480,
            title: "Slow Horses",
            mediaType: .tvShow,
            overview: "This quick-witted espionage drama follows a dysfunctional team of MI5 agents—and their obnoxious boss, the notorious Jackson Lamb—as they navigate the espionage world's smoke and mirrors to defend England from sinister forces.",
            posterPath: "/w2jauz2PeSjFQifDObI3qDen4f7.jpg",
            backdropPath: "/wPJgjOfsFUny1WBo53Q9xtIMSs.jpg",
            voteAverage: 8.3,
            voteCount: 1980,
            releaseDateString: "2022-04-01",
            genreNames: ["Thriller", "Crime", "Drama"],
            runtimeMinutes: 48,
            tagline: "The rejects are the vanguard.",
            certification: "TV-MA",
            streamingProviders: [.appleTV],
            trailers: [VideoTrailer(id: "t6", name: "Season 4 Trailer", key: "dE8m6Hq4P9Y")],
            cast: [
                CastMember(id: 17, name: "Gary Oldman", character: "Jackson Lamb"),
                CastMember(id: 18, name: "Jack Lowden", character: "River Cartwright"),
                CastMember(id: 19, name: "Kristin Scott Thomas", character: "Diana Taverner")
            ]
        ),
        MediaItem(
            id: 194764,
            title: "The Penguin",
            mediaType: .tvShow,
            overview: "Following the events of The Batman, Oswald Cobblepot begins his ruthless climb to seize control of Gotham City's criminal underworld as an all-out turf war brews.",
            posterPath: "/vOWcqC4oDQws1doDWLO7d3dh5qc.jpg",
            backdropPath: "/7tGvH4PYRbzO9W6wcGxqyU2FZJd.jpg",
            voteAverage: 8.8,
            voteCount: 3400,
            releaseDateString: "2024-09-19",
            genreNames: ["Crime", "Drama"],
            runtimeMinutes: 60,
            tagline: "Gotham belongs to whoever takes it.",
            certification: "TV-MA",
            streamingProviders: [.max],
            trailers: [VideoTrailer(id: "t7", name: "Official Trailer", key: "sfJsmvvgL6s")],
            cast: [
                CastMember(id: 20, name: "Colin Farrell", character: "Oz Cobb"),
                CastMember(id: 21, name: "Cristin Milioti", character: "Sofia Falcone")
            ]
        ),
        MediaItem(
            id: 126308,
            title: "Shōgun",
            mediaType: .tvShow,
            overview: "When a mysterious European ship is found marooned in a nearby fishing village, Lord Yoshii Toranaga discovers secrets that could tip the scales of power and devastate his formidable enemies in 17th-century feudal Japan.",
            posterPath: "/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg",
            backdropPath: "/bwSmgmd90hCWwqOKQYTEraeOZhJ.jpg",
            voteAverage: 8.9,
            voteCount: 5200,
            releaseDateString: "2024-02-27",
            genreNames: ["Drama", "History", "War"],
            runtimeMinutes: 60,
            tagline: "Fate is a tethered hawk.",
            certification: "TV-MA",
            streamingProviders: [.disneyPlus],
            trailers: [VideoTrailer(id: "t8", name: "Official Trailer", key: "yCMX2L7x09E")],
            cast: [
                CastMember(id: 22, name: "Hiroyuki Sanada", character: "Lord Toranaga"),
                CastMember(id: 23, name: "Cosmo Jarvis", character: "John Blackthorne"),
                CastMember(id: 24, name: "Anna Sawai", character: "Toda Mariko")
            ]
        )
    ]
    
    public static let streamingCatalog: [Int: [MediaItem]] = [
        StreamingProvider.netflix.id: [
            MediaItem(
                id: 94028,
                title: "Ripley",
                mediaType: .tvShow,
                overview: "A grifter drawn into a world of wealth and privilege after taking a unique job in Italy finds himself entangled in a complex web of deception, fraud, and murder.",
                posterPath: "/rpSo8z9alultGVTqQ3dkLEyU8xx.jpg",
                backdropPath: "/erpjqVdJLpDQJjsbxaSJmMwvcqd.jpg",
                voteAverage: 8.1,
                voteCount: 1420,
                releaseDateString: "2024-04-04",
                genreNames: ["Crime", "Thriller", "Drama"],
                runtimeMinutes: 55,
                tagline: "He had a taste for the finer things.",
                certification: "TV-MA",
                streamingProviders: [.netflix]
            ),
            MediaItem(
                id: 241259,
                title: "Baby Reindeer",
                mediaType: .tvShow,
                overview: "When a struggling comedian shows one kind gesture to a vulnerable woman, an obsessive stalking nightmare erupts that forces both to confront deeply buried trauma.",
                posterPath: "/tN9OcbkAOPwHSr1sgMornZtQZBx.jpg",
                backdropPath: "/Y5P4Q3q8nrruZ9aD3wXeJS2Plg.jpg",
                voteAverage: 7.9,
                voteCount: 2890,
                releaseDateString: "2024-04-11",
                genreNames: ["Drama", "Biography"],
                runtimeMinutes: 32,
                tagline: "A true story about obsession.",
                certification: "TV-MA",
                streamingProviders: [.netflix]
            ),
            MediaItem(
                id: 661374,
                title: "Glass Onion: A Knives Out Mystery",
                mediaType: .movie,
                overview: "World-famous detective Benoit Blanc heads to Greece to peel back the layers of a mystery surrounding a tech billionaire and his eclectic crew of friends.",
                posterPath: "/vDGr1YdrlfbU9wxTOdpf3zChmv9.jpg",
                backdropPath: "/y3uOfZAYwLkbvhunswBCskNMrfI.jpg",
                voteAverage: 7.5,
                voteCount: 5400,
                releaseDateString: "2022-12-23",
                genreNames: ["Comedy", "Mystery", "Thriller"],
                runtimeMinutes: 139,
                tagline: "You can't solve it alone.",
                certification: "PG-13",
                streamingProviders: [.netflix],
                logoPath: "/8sAA3GbGFQqaJYyOCiJD9n0fVDI.png"
            ),
            MediaItem(
                id: 800158,
                title: "The Killer",
                mediaType: .movie,
                overview: "After a fateful near-miss, an assassin battles his employers, and himself, on an international manhunt he insists isn't personal.",
                posterPath: "/ipkcgvN7h3yZnbYowthloHLKsf4.jpg",
                backdropPath: "/f9Atch0jlzcOT9RbF8UccqfNOpd.jpg",
                voteAverage: 7.3,
                voteCount: 2900,
                releaseDateString: "2023-11-10",
                genreNames: ["Action", "Thriller", "Crime"],
                runtimeMinutes: 118,
                tagline: "Execution is everything.",
                certification: "R",
                streamingProviders: [.netflix]
            ),
            MediaItem(
                id: 906126,
                title: "Society of the Snow",
                mediaType: .movie,
                overview: "In 1972, a Uruguayan rugby team's flight crashes onto a glacier in the heart of the Andes, where survivors must resort to extreme measures to stay alive.",
                posterPath: "/2e853FDVSIso600RqAMunPxiZjq.jpg",
                backdropPath: "/md848EEPm3dHZOqwGxxTVwH2vu5.jpg",
                voteAverage: 8.0,
                voteCount: 3100,
                releaseDateString: "2023-12-15",
                genreNames: ["Drama", "Adventure", "History"],
                runtimeMinutes: 144,
                tagline: "The impossible journey home.",
                certification: "R",
                streamingProviders: [.netflix]
            ),
            MediaItem(
                id: 66732,
                title: "Stranger Things",
                mediaType: .tvShow,
                overview: "When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces and one strange little girl.",
                posterPath: "/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg",
                backdropPath: "/56v2KjBlU4XaOv9rVYEQypROD7P.jpg",
                voteAverage: 8.6,
                voteCount: 16500,
                releaseDateString: "2016-07-15",
                genreNames: ["Sci-Fi", "Drama", "Mystery"],
                runtimeMinutes: 50,
                tagline: "Every ending has a beginning.",
                certification: "TV-14",
                streamingProviders: [.netflix]
            )
        ],
        StreamingProvider.appleTV.id: [
            trendingItems[0], // Severance
            trendingItems[1], // Slow Horses
            MediaItem(
                id: 466420,
                title: "Killers of the Flower Moon",
                mediaType: .movie,
                overview: "When oil is discovered in 1920s Oklahoma under Osage Nation land, the Osage people are murdered one by one until the FBI steps in to unravel the conspiracy.",
                posterPath: "/dB6Krk806zeqd0YNp2ngQ9zXteH.jpg",
                backdropPath: "/nQJ3RWiSMX5FB8wx4cIooR44B1s.jpg",
                voteAverage: 7.9,
                voteCount: 3100,
                releaseDateString: "2023-10-20",
                genreNames: ["Crime", "Drama", "History"],
                runtimeMinutes: 206,
                tagline: "Can you spot the wolves in this picture?",
                certification: "R",
                streamingProviders: [.appleTV],
                logoPath: "/1byCcdBqQi9CI50xQTA4cjmVCxf.png"
            ),
            MediaItem(
                id: 97546,
                title: "Ted Lasso",
                mediaType: .tvShow,
                overview: "An American college football coach is hired to manage a struggling British soccer team, attempting to win over skeptical players and town with optimism.",
                posterPath: "/uRHsiw1wLxPHFXkkv4Ix1s0O6f4.jpg",
                backdropPath: "/nE94ejEbzNCU48bW1oju0dqBONz.jpg",
                voteAverage: 8.5,
                voteCount: 4100,
                releaseDateString: "2020-08-14",
                genreNames: ["Comedy", "Drama"],
                runtimeMinutes: 35,
                tagline: "Kindness makes a comeback.",
                certification: "TV-MA",
                streamingProviders: [.appleTV],
                logoPath: "/89zpmSMZYx5jShGyr14byW8L1CX.png"
            ),
            MediaItem(
                id: 776503,
                title: "CODA",
                mediaType: .movie,
                overview: "As a CODA (Child of Deaf Adults), Ruby is the only hearing person in her deaf family. When the family's fishing business is threatened, Ruby finds herself torn between pursuing her love of music and her fear of abandoning her parents.",
                posterPath: "/BzVjmm8l23rPsijLiNLUzuQtyd.jpg",
                backdropPath: "/v85FlkbMYKa5du1glm0YfYNsL2n.jpg",
                voteAverage: 8.1,
                voteCount: 2200,
                releaseDateString: "2021-08-13",
                genreNames: ["Drama", "Music"],
                runtimeMinutes: 111,
                tagline: "Every family has its own language.",
                certification: "PG-13",
                streamingProviders: [.appleTV]
            ),
            MediaItem(
                id: 125988,
                title: "Silo",
                mediaType: .tvShow,
                overview: "In a ruined and toxic future, thousands live in a giant underground silo. When its sheriff breaks a cardinal rule, an engineer uncovers shocking truths about their world.",
                posterPath: "/gMYZZvnkVNTqSVnVCphWbPXwWwb.jpg",
                backdropPath: "/1Qf5ClZJpmEPJgBqBB03UvCVXzO.jpg",
                voteAverage: 8.3,
                voteCount: 2100,
                releaseDateString: "2023-05-05",
                genreNames: ["Sci-Fi", "Drama"],
                runtimeMinutes: 55,
                tagline: "The truth will surface.",
                certification: "TV-MA",
                streamingProviders: [.appleTV]
            )
        ],
        StreamingProvider.disneyPlus.id: [
            trendingItems[3], // Shogun
            MediaItem(
                id: 82856,
                title: "The Mandalorian",
                mediaType: .tvShow,
                overview: "After the fall of the Galactic Empire, a lone gunfighter makes his way through the outer reaches of the lawless galaxy.",
                posterPath: "/sWgBv7LV2PRoQgkxwlibdGXKz1S.jpg",
                backdropPath: "/9zcbqSxdsRMZWHYtyCd1nXPr2xq.jpg",
                voteAverage: 8.4,
                voteCount: 9800,
                releaseDateString: "2019-11-12",
                genreNames: ["Sci-Fi", "Action", "Adventure"],
                runtimeMinutes: 40,
                tagline: "Bounty hunting is a complicated profession.",
                certification: "TV-14",
                streamingProviders: [.disneyPlus]
            ),
            MediaItem(
                id: 84958,
                title: "Loki",
                mediaType: .tvShow,
                overview: "After stealing the Tesseract during the events of Avengers: Endgame, an alternate version of Loki is brought to the mysterious Time Variance Authority.",
                posterPath: "/kEl2t3OhXc3Zb9FBh1AuYzRTgZp.jpg",
                backdropPath: "/q3jHCb4dMfYF6ojikKuHd6LscxC.jpg",
                voteAverage: 8.2,
                voteCount: 8200,
                releaseDateString: "2021-06-09",
                genreNames: ["Sci-Fi", "Action", "Adventure"],
                runtimeMinutes: 52,
                tagline: "Loki's time has come.",
                certification: "TV-14",
                streamingProviders: [.disneyPlus]
            ),
            MediaItem(
                id: 792307,
                title: "Poor Things",
                mediaType: .movie,
                overview: "Brought back to life by an unorthodox scientist, a young woman runs off with a debauched lawyer on a whirlwind adventure across continents.",
                posterPath: "/kCGlIMHnOm8JPXq3rXM6c5wMxcT.jpg",
                backdropPath: "/zh6IdheEYinU4TPtorWsjx6qPQE.jpg",
                voteAverage: 7.8,
                voteCount: 4200,
                releaseDateString: "2023-12-08",
                genreNames: ["Sci-Fi", "Romance", "Comedy"],
                runtimeMinutes: 141,
                tagline: "She's like nothing you've ever seen.",
                certification: "R",
                streamingProviders: [.disneyPlus]
            ),
            MediaItem(
                id: 136315,
                title: "The Bear",
                mediaType: .tvShow,
                overview: "A young fine-dining chef comes home to Chicago to run his family Italian beef sandwich shop after a heartbreaking death in his family.",
                posterPath: "/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg",
                backdropPath: "/eh7hIGLq7IhddgOPYyprCbz8JtH.jpg",
                voteAverage: 8.6,
                voteCount: 3900,
                releaseDateString: "2022-06-23",
                genreNames: ["Drama", "Comedy"],
                runtimeMinutes: 30,
                tagline: "Every second counts.",
                certification: "TV-MA",
                streamingProviders: [.disneyPlus],
                logoPath: "/yuHeksANqi7f2E7oQrw1A2r50Dh.png"
            )
        ],
        StreamingProvider.primeVideo.id: [
            MediaItem(
                id: 76479,
                title: "The Boys",
                mediaType: .tvShow,
                overview: "A fun and irreverent take on what happens when superheroes abuse their superpowers rather than use them for good.",
                posterPath: "/in1R2dDc421JxsoRWaIIAqVI2KE.jpg",
                backdropPath: "/n6vVs6z8obNbExdD3QHTr4Utu1Z.jpg",
                voteAverage: 8.5,
                voteCount: 9400,
                releaseDateString: "2019-07-26",
                genreNames: ["Action", "Sci-Fi", "Comedy"],
                runtimeMinutes: 60,
                tagline: "Never meet your heroes.",
                certification: "TV-MA",
                streamingProviders: [.primeVideo],
                logoPath: "/lrs0W28PxcamremKIvQvkheiNp9.png"
            ),
            MediaItem(
                id: 106379,
                title: "Fallout",
                mediaType: .tvShow,
                overview: "In a future, post-apocalyptic Los Angeles brought about by nuclear decimation, citizens must live in underground bunkers to protect themselves from radiation, mutants and bandits.",
                posterPath: "/c15BtJxCXMrISLVmysdsnZUPQft.jpg",
                backdropPath: "/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg",
                voteAverage: 8.4,
                voteCount: 3800,
                releaseDateString: "2024-04-10",
                genreNames: ["Sci-Fi", "Action", "Drama"],
                runtimeMinutes: 62,
                tagline: "The end of the world is just the beginning.",
                certification: "TV-MA",
                streamingProviders: [.primeVideo]
            ),
            MediaItem(
                id: 843527,
                title: "The Idea of You",
                mediaType: .movie,
                overview: "Solène Marchand, a 40-year-old single mother, begins an unexpected romance with 24-year-old Hayes Campbell, the lead singer of August Moon, the hottest boy band on the planet.",
                posterPath: "/Y5P4Q3q8nrruZ9aD3wXeJS2Plg.jpg",
                backdropPath: "/sI6uCeF8mUlZx22mFfHSi9W3XQ9.jpg",
                voteAverage: 7.4,
                voteCount: 1600,
                releaseDateString: "2024-05-02",
                genreNames: ["Romance", "Comedy", "Drama"],
                runtimeMinutes: 115,
                tagline: "Age is just a number.",
                certification: "R",
                streamingProviders: [.primeVideo],
                logoPath: "/fcIKzqbhtlUeWOvYjFdkR8rZOAC.png"
            ),
            MediaItem(
                id: 359410,
                title: "Road House",
                mediaType: .movie,
                overview: "Ex-UFC fighter Dalton takes a job as a bouncer at a Florida Keys roadhouse, only to discover that this paradise is not all it seems.",
                posterPath: "/fDEdtS4P0gJsxHDIt8dG8TR5dx1.jpg",
                backdropPath: "/clFFCapyGpE7KD4Jsu5pUbFBZF4.jpg",
                voteAverage: 7.0,
                voteCount: 2200,
                releaseDateString: "2024-03-21",
                genreNames: ["Action", "Thriller"],
                runtimeMinutes: 121,
                tagline: "Fighting is what he does.",
                certification: "R",
                streamingProviders: [.primeVideo]
            ),
            MediaItem(
                id: 108978,
                title: "Reacher",
                mediaType: .tvShow,
                overview: "Jack Reacher, a veteran military police investigator, enters civilian life travelling from town to town across the United States.",
                posterPath: "/f1VCQIG2iCyOookdgOzwtUpwWC0.jpg",
                backdropPath: "/pF0qkRsrHkdYadPWY9AMeFZfcwk.jpg",
                voteAverage: 8.1,
                voteCount: 2400,
                releaseDateString: "2022-02-03",
                genreNames: ["Action", "Crime", "Drama"],
                runtimeMinutes: 50,
                tagline: "Payback is coming.",
                certification: "TV-MA",
                streamingProviders: [.primeVideo]
            )
        ],
        StreamingProvider.max.id: [
            freshFromTheatres[0], // Dune 2
            freshFromTheatres[1], // Civil War
            freshFromTheatres[2], // Furiosa
            trendingItems[2],      // The Penguin
            MediaItem(
                id: 94997,
                title: "House of the Dragon",
                mediaType: .tvShow,
                overview: "The Targaryen dynasty is at the absolute apex of its power, with more than 15 dragons under their yoke. Most empires crumble from such heights.",
                posterPath: "/7V0Ebks0GgpKvQ7QbLAIdX5dos4.jpg",
                backdropPath: "/577eXC8wFQT0eUrJcgznSiFPRmk.jpg",
                voteAverage: 8.4,
                voteCount: 4700,
                releaseDateString: "2022-08-21",
                genreNames: ["Drama", "Action", "Fantasy"],
                runtimeMinutes: 60,
                tagline: "All must choose.",
                certification: "TV-MA",
                streamingProviders: [.max]
            ),
            MediaItem(
                id: 414906,
                title: "The Batman",
                mediaType: .movie,
                overview: "In his second year of fighting crime, Batman uncovers corruption in Gotham City that connects to his own family while facing a serial killer known as the Riddler.",
                posterPath: "/74xTEgt7R36Fpooo50r9T25onhq.jpg",
                backdropPath: "/b0PlSFdDwbyK0cf5RxwDpaOJQvQ.jpg",
                voteAverage: 7.7,
                voteCount: 9600,
                releaseDateString: "2022-03-04",
                genreNames: ["Crime", "Mystery", "Thriller"],
                runtimeMinutes: 176,
                tagline: "Unmask the truth.",
                certification: "PG-13",
                streamingProviders: [.max]
            )
        ],
        StreamingProvider.paramountPlus.id: [
            MediaItem(
                id: 73586,
                title: "Yellowstone",
                mediaType: .tvShow,
                overview: "Follow the Dutton family, led by John Dutton, who controls the largest contiguous ranch in the United States, under constant attack by those it borders.",
                posterPath: "/peNC0eyc3TQJa6x4TdKcBPNP4t0.jpg",
                backdropPath: "/2NhBFUTg5KVBmGwafxtLwVdsqrr.jpg",
                voteAverage: 8.2,
                voteCount: 2600,
                releaseDateString: "2018-06-20",
                genreNames: ["Western", "Drama"],
                runtimeMinutes: 50,
                tagline: "Power has a price.",
                certification: "TV-MA",
                streamingProviders: [.paramountPlus]
            ),
            MediaItem(
                id: 361743,
                title: "Top Gun: Maverick",
                mediaType: .movie,
                overview: "After more than thirty years of service as one of the Navy’s top aviators, Pete Mitchell is where he belongs, pushing the envelope as a courageous test pilot.",
                posterPath: "/n0YuM4f5lvGAP6MAW2kBIzugXnc.jpg",
                backdropPath: "/AaV1YIdWKnjAIAOe8UUKBFm327v.jpg",
                voteAverage: 8.3,
                voteCount: 8700,
                releaseDateString: "2022-05-27",
                genreNames: ["Action", "Drama"],
                runtimeMinutes: 130,
                tagline: "Feel the need for speed.",
                certification: "PG-13",
                streamingProviders: [.paramountPlus]
            ),
            MediaItem(
                id: 153312,
                title: "Tulsa King",
                mediaType: .tvShow,
                overview: "Just after he is released from prison after 25 years, New York mafia capo Dwight Manfredi is unceremoniously exiled by his boss to set up shop in Tulsa, Oklahoma.",
                posterPath: "/rOYLWCdAifpUtPlTf1WHxyaxeMt.jpg",
                backdropPath: "/mNHRGO1gFpR2CYZdANe72kcKq7G.jpg",
                voteAverage: 8.0,
                voteCount: 1400,
                releaseDateString: "2022-11-13",
                genreNames: ["Crime", "Drama"],
                runtimeMinutes: 42,
                tagline: "Conquering new territory.",
                certification: "TV-MA",
                streamingProviders: [.paramountPlus]
            )
        ],
        StreamingProvider.mubi.id: [
            MediaItem(
                id: 965150,
                title: "Aftersun",
                mediaType: .movie,
                overview: "Sophie reflects on the shared joy and private melancholy of a holiday she took with her father twenty years earlier as memories fill the gaps between footage.",
                posterPath: "/evKz85EKouVbIr51zy5fOtpNRPg.jpg",
                backdropPath: "/d5l2ITQvpgP0dcWCAG6PUvp8YZw.jpg",
                voteAverage: 7.8,
                voteCount: 1200,
                releaseDateString: "2022-10-21",
                genreNames: ["Drama"],
                runtimeMinutes: 102,
                tagline: "Memories that stay.",
                certification: "R",
                streamingProviders: [.mubi],
                logoPath: "/hZCqSZbRUSUyWIXglKtwuoM0AiV.png"
            ),
            MediaItem(
                id: 666277,
                title: "Past Lives",
                mediaType: .movie,
                overview: "Nora and Hae Sung, two deeply connected childhood friends, are wrested apart after Nora's family emigrates from South Korea. Decades later, they are reunited.",
                posterPath: "/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg",
                backdropPath: "/7HR38hMBl23lf38MAN63y4pKsHz.jpg",
                voteAverage: 7.9,
                voteCount: 1900,
                releaseDateString: "2023-06-02",
                genreNames: ["Romance", "Drama"],
                runtimeMinutes: 106,
                tagline: "In-Yun: connected across lifetimes.",
                certification: "PG-13",
                streamingProviders: [.mubi],
                logoPath: "/7ZS4EoBQrTUatmLfNW6GsJQIBrO.png"
            )
        ],
        StreamingProvider.crunchyroll.id: [
            MediaItem(
                id: 85937,
                title: "Demon Slayer: Kimetsu no Yaiba",
                mediaType: .tvShow,
                overview: "It is the Taisho Period in Japan. Tanjiro, a kindhearted boy who sells charcoal for a living, finds his family slaughtered by a demon.",
                posterPath: "/xUfRZu2mi8jH6SzQEJGP6tjBuYj.jpg",
                backdropPath: "/3GQKYh6Trm8pxd2AypovoYQf4Ay.jpg",
                voteAverage: 8.7,
                voteCount: 6100,
                releaseDateString: "2019-04-06",
                genreNames: ["Animation", "Action", "Fantasy"],
                runtimeMinutes: 24,
                tagline: "Sever the bonds of fate.",
                certification: "TV-MA",
                streamingProviders: [.crunchyroll]
            ),
            MediaItem(
                id: 95479,
                title: "Jujutsu Kaisen",
                mediaType: .tvShow,
                overview: "Yuji Itadori is a boy with tremendous physical strength, though he lives a completely ordinary high school life. One day, to save a classmate, he eats the finger of Ryomen Sukuna.",
                posterPath: "/6qQzMJG27XOJsyAEEIisoJB45j2.jpg",
                backdropPath: "/qpin8cASXEVtwhzNsprHYFiOAGk.jpg",
                voteAverage: 8.6,
                voteCount: 3800,
                releaseDateString: "2020-10-03",
                genreNames: ["Animation", "Action", "Supernatural"],
                runtimeMinutes: 24,
                tagline: "Embrace the curse.",
                certification: "TV-MA",
                streamingProviders: [.crunchyroll],
                logoPath: "/tEmqJ1k4MdjuaKaetn8wGyZGcyC.png"
            )
        ],
        StreamingProvider.nowTV.id: [
            MediaItem(
                id: 206829,
                title: "The Regime",
                mediaType: .tvShow,
                overview: "Follow the story of a modern European regime as it begins to unravel over the course of a year within the palace walls.",
                posterPath: "/ztqPixNyezY6pWSNIP2AlhwPMO0.jpg",
                backdropPath: "/lp6Rsgid52BIlzYxWDURFSZZU6m.jpg",
                voteAverage: 7.2,
                voteCount: 420,
                releaseDateString: "2024-03-03",
                genreNames: ["Drama", "Comedy"],
                runtimeMinutes: 56,
                tagline: "All power fades.",
                certification: "TV-MA",
                streamingProviders: [.nowTV],
                logoPath: "/j8eLuEbl00mOl08Bu95tEpdnRo7.png"
            ),
            MediaItem(
                id: 787699,
                title: "Wonka",
                mediaType: .movie,
                overview: "Willy Wonka – chock-full of ideas and determined to change the world one delectable bite at a time – is determined to prove that the best things in life begin with a dream.",
                posterPath: "/qhb1qOilapbapxWQn9jtRCMwXJF.jpg",
                backdropPath: "/uIk2g2bRkNwNywKZIhC5oIU94Kh.jpg",
                voteAverage: 7.2,
                voteCount: 3100,
                releaseDateString: "2023-12-06",
                genreNames: ["Comedy", "Family", "Fantasy"],
                runtimeMinutes: 116,
                tagline: "Witness the origin.",
                certification: "PG",
                streamingProviders: [.nowTV],
                logoPath: "/7Rq0Bqd9xFeTz0lx19OLj51ovfW.png"
            )
        ],
        StreamingProvider.bbcIPlayer.id: [
            MediaItem(
                id: 60574,
                title: "Peaky Blinders",
                mediaType: .tvShow,
                overview: "A gangster family epic set in 1919 Birmingham, England and centered on a gang who sew razor blades in the peaks of their caps, and their fierce boss Tommy Shelby.",
                posterPath: "/vUUqzWa2LnHIVqkaKVlVGkVcZIW.jpg",
                backdropPath: "/dzq83RHwQcnP6WGJ6YkenIqeaa5.jpg",
                voteAverage: 8.6,
                voteCount: 9500,
                releaseDateString: "2013-09-12",
                genreNames: ["Drama", "Crime"],
                runtimeMinutes: 60,
                tagline: "By order of the Peaky Blinders.",
                certification: "TV-MA",
                streamingProviders: [.bbcIPlayer]
            ),
            MediaItem(
                id: 61244,
                title: "Happy Valley",
                mediaType: .tvShow,
                overview: "Catherine Cawood is a strong-willed police sergeant in West Yorkshire, still coming to terms with the suicide of her teenage daughter eight years earlier.",
                posterPath: "/xZK5iQSrn2mouZEk2PwyLPCwa4u.jpg",
                backdropPath: "/jr02ooBDhTnymi65dj1vXn2o7sx.jpg",
                voteAverage: 8.4,
                voteCount: 1100,
                releaseDateString: "2014-04-29",
                genreNames: ["Crime", "Drama"],
                runtimeMinutes: 58,
                tagline: "Justice takes resilience.",
                certification: "TV-MA",
                streamingProviders: [.bbcIPlayer],
                logoPath: "/9BIYpgFT4vqNATQI5kc2EMIUang.png"
            )
        ],
        StreamingProvider.itvx.id: [
            MediaItem(
                id: 1427,
                title: "Broadchurch",
                mediaType: .tvShow,
                overview: "The murder of a young boy in a small coastal town brings a media frenzy, which threatens to tear the community apart.",
                posterPath: "/2NhBFUTg5KVBmGwafxtLwVdsqrr.jpg",
                backdropPath: "/9CkwC4rou9468XMLTXaB6bZ0frx.jpg",
                voteAverage: 8.2,
                voteCount: 1600,
                releaseDateString: "2013-03-04",
                genreNames: ["Crime", "Drama", "Mystery"],
                runtimeMinutes: 48,
                tagline: "Secrets run deep.",
                certification: "TV-14",
                streamingProviders: [.itvx],
                logoPath: "/u20mcBZHZCTFSRA8Mm7PJP5qIF8.png"
            ),
            MediaItem(
                id: 645689,
                title: "The Duke",
                mediaType: .movie,
                overview: "In 1961, Kempton Bunton, a 60-year-old taxi driver, stole Goya's portrait of the Duke of Wellington from the National Gallery in London.",
                posterPath: "/zXlj7NgSWg0NbK2zfUh0nbGZVuz.jpg",
                backdropPath: "/wddNG1To5jUwmX8gwcGjZSpckwg.jpg",
                voteAverage: 7.2,
                voteCount: 450,
                releaseDateString: "2022-02-25",
                genreNames: ["Comedy", "Drama", "History"],
                runtimeMinutes: 96,
                tagline: "An extraordinarily true heist.",
                certification: "PG-13",
                streamingProviders: [.itvx],
                logoPath: "/9tMPGMBWuZr21MxrKLGa2CQGGQ6.png"
            )
        ],
        StreamingProvider.channel4.id: [
            MediaItem(
                id: 76148,
                title: "Derry Girls",
                mediaType: .tvShow,
                overview: "Amidst the political conflict of Northern Ireland in the 1990s, five high school friends navigate the universal challenges of being a teenager.",
                posterPath: "/btIm8LOtm2qgHIA2IHmQJvD1Mju.jpg",
                backdropPath: "/nQyQ4c8DUvXra1LDWnNfV9QJluD.jpg",
                voteAverage: 8.3,
                voteCount: 1200,
                releaseDateString: "2018-01-04",
                genreNames: ["Comedy"],
                runtimeMinutes: 22,
                tagline: "Growing up in a turbulent time.",
                certification: "TV-MA",
                streamingProviders: [.channel4]
            ),
            MediaItem(
                id: 116174,
                title: "It's A Sin",
                mediaType: .tvShow,
                overview: "A chronicle of four friends during a decade in which everything changed, including the rise of AIDS in 1980s London.",
                posterPath: "/tUaNS4b5TIiP1SwpHCYCbUoGpHG.jpg",
                backdropPath: "/3rVG321Ne5nSh5IeO5hlLn6dFyA.jpg",
                voteAverage: 8.5,
                voteCount: 950,
                releaseDateString: "2021-01-22",
                genreNames: ["Drama"],
                runtimeMinutes: 48,
                tagline: "Remember the days.",
                certification: "TV-MA",
                streamingProviders: [.channel4],
                logoPath: "/jdcPKcDVPWgXPrSIv5oaDB0n0H8.png"
            )
        ],
        StreamingProvider.skyGo.id: [
            MediaItem(
                id: 85021,
                title: "Gangs of London",
                mediaType: .tvShow,
                overview: "When the head of a criminal organization is assassinated, the sudden power vacuum creates a battle between rival gangs on the streets of London.",
                posterPath: "/fVgwa6wGw9ddGM5O7mqrrwB6gHK.jpg",
                backdropPath: "/9aJ6KwLASA38WzdMRVjk7ILpuTv.jpg",
                voteAverage: 7.9,
                voteCount: 880,
                releaseDateString: "2020-04-23",
                genreNames: ["Action", "Crime", "Drama"],
                runtimeMinutes: 58,
                tagline: "Blood runs the city.",
                certification: "TV-MA",
                streamingProviders: [.skyGo],
                logoPath: "/m6bPFRegqJhO0MNvQUHvYWffLGt.png"
            ),
            MediaItem(
                id: 866398,
                title: "The Beekeeper",
                mediaType: .movie,
                overview: "One man's brutal campaign for vengeance takes on national stakes after he is revealed to be a former operative of a powerful and clandestine organization.",
                posterPath: "/A7EByudX0eOzlkQ2FIbogzyazm2.jpg",
                backdropPath: "/f0ACHVpV707zqu4etZrXnWNdSgL.jpg",
                voteAverage: 7.4,
                voteCount: 2600,
                releaseDateString: "2024-01-12",
                genreNames: ["Action", "Thriller"],
                runtimeMinutes: 105,
                tagline: "Expose the corrupt.",
                certification: "R",
                streamingProviders: [.skyGo]
            )
        ]
    ]
    
    public static let newReleases: [MediaItem] = [
        freshFromTheatres[0],
        freshFromTheatres[1],
        freshFromTheatres[2],
        trendingItems[2]
    ]
    
    public static let topRated: [MediaItem] = [
        MediaItem(
            id: 238,
            title: "The Godfather",
            mediaType: .movie,
            overview: "Spanning the years 1945 to 1955, a chronicle of the fictional Italian-American Corleone crime family. When organized crime family patriarch, Vito Corleone, barely survives an attempt on his life, his youngest son, Michael, steps in to take care of the would-be killers.",
            posterPath: "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
            backdropPath: "/tSPT36ZKlP2WVHJLM4cQPLSzv3b.jpg",
            voteAverage: 9.2,
            voteCount: 19800,
            releaseDateString: "1972-03-14",
            genreNames: ["Drama", "Crime"],
            runtimeMinutes: 175,
            tagline: "An offer you can't refuse.",
            certification: "R",
            streamingProviders: [.primeVideo]
        ),
        MediaItem(
            id: 157336,
            title: "Interstellar",
            mediaType: .movie,
            overview: "The adventures of a group of explorers who make use of a newly discovered wormhole to surpass the limitations on human space travel and conquer the vast distances involved in an interstellar voyage.",
            posterPath: "/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg",
            backdropPath: "/xJHokMbljvjADYdit5fK5VQsXEG.jpg",
            voteAverage: 8.8,
            voteCount: 34100,
            releaseDateString: "2014-11-05",
            genreNames: ["Sci-Fi", "Drama", "Adventure"],
            runtimeMinutes: 169,
            tagline: "Mankind was born on Earth. It was never meant to die here.",
            certification: "PG-13",
            streamingProviders: [.primeVideo]
        ),
        MediaItem(
            id: 129,
            title: "Spirited Away",
            mediaType: .movie,
            overview: "A young girl, Chihiro, becomes trapped in a strange new world of spirits. When her parents undergo a mysterious transformation, she must call upon the courage she never knew she had to rescue her family.",
            posterPath: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
            backdropPath: "/dyJvKsNs2KP8qQnAXbRwDjblViy.jpg",
            voteAverage: 8.9,
            voteCount: 16200,
            releaseDateString: "2001-07-20",
            genreNames: ["Animation", "Family", "Fantasy"],
            runtimeMinutes: 125,
            tagline: "Nothing that happens is ever forgotten.",
            certification: "PG",
            streamingProviders: [.max]
        )
    ]
    
    public static let upcoming: [MediaItem] = [
        MediaItem(
            id: 806704,
            title: "The Batman: Part II",
            mediaType: .movie,
            overview: "The continuing saga of the Dark Knight in Gotham City as Bruce Wayne faces new threats arising from the criminal underworld.",
            posterPath: "/r5fl4aMsmTjgc8DdDqQaM84roWp.jpg",
            backdropPath: "/4uaHnYDDpUTj0nCg6YqBKab50YW.jpg",
            voteAverage: 8.5,
            voteCount: 1420,
            releaseDateString: "2026-10-02",
            genreNames: ["Action", "Crime", "Drama"],
            runtimeMinutes: 165,
            tagline: "Unmask the truth.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "bm2_1", name: "Teaser Announcement", key: "mqqft2x_Aa4")],
            cast: [
                CastMember(id: 11288, name: "Robert Pattinson", character: "Bruce Wayne / The Batman"),
                CastMember(id: 6573, name: "Andy Serkis", character: "Alfred Pennyworth"),
                CastMember(id: 2178, name: "Colin Farrell", character: "Oswald Cobblepot / The Penguin")
            ],
            logoPath: "/bdegQBZoIM1bqB0zjk6K1pb9nWY.png",
            inCinemas: false
        ),
        MediaItem(
            id: 83533,
            title: "Avatar: Fire and Ash",
            mediaType: .movie,
            overview: "Jake Sully and Neytiri encounter a new, aggressive volcanic clan of Na'vi known as the Ash People on Pandora.",
            posterPath: "/bRBeSHfGHwkEpImlhxPmOcUsaeg.jpg",
            backdropPath: "/u8DU5fkLoM5tTRukzPC31oGPxaQ.jpg",
            voteAverage: 8.4,
            voteCount: 1650,
            releaseDateString: "2026-12-18",
            genreNames: ["Sci-Fi", "Adventure", "Action"],
            runtimeMinutes: 185,
            tagline: "Return to Pandora.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "av3_1", name: "Official Teaser", key: "d9MyW72ELq0")],
            cast: [
                CastMember(id: 65731, name: "Sam Worthington", character: "Jake Sully"),
                CastMember(id: 8691, name: "Zoe Saldana", character: "Neytiri"),
                CastMember(id: 10205, name: "Sigourney Weaver", character: "Kiri")
            ],
            logoPath: "/qzuSPiHF08bUZXPaXST24ANfoqK.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1003596,
            title: "Avengers: Doomsday",
            mediaType: .movie,
            overview: "The Avengers assemble to confront Doctor Doom across the collapsing multiverse in an epic conflict that will reshape reality.",
            posterPath: "/jzPwsojjFStf5lR5Nm07w2hH56G.jpg",
            backdropPath: "/s4v0UX1anfXm0UvloLsTTJ4v222.jpg",
            voteAverage: 8.6,
            voteCount: 2200,
            releaseDateString: "2026-12-18",
            genreNames: ["Action", "Sci-Fi", "Adventure"],
            runtimeMinutes: 160,
            tagline: "A new threat emerges.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "avd1", name: "Hall H Announcement", key: "NOhDyZJ_318")],
            cast: [
                CastMember(id: 3223, name: "Robert Downey Jr.", character: "Victor von Doom / Doctor Doom"),
                CastMember(id: 16828, name: "Chris Evans", character: "Steve Rogers"),
                CastMember(id: 74568, name: "Chris Hemsworth", character: "Thor")
            ],
            logoPath: "/enJPk9TdYB4zCO1mIwiRYAb5yqY.png",
            inCinemas: false
        ),
        MediaItem(
            id: 569094,
            title: "Spider-Man: Beyond the Spider-Verse",
            mediaType: .movie,
            overview: "Miles Morales travels across parallel universes to save his father and rectify the fate of the Spider-Verse against overwhelming multiversal odds.",
            posterPath: "/9KAe39xqyZnv9J4W3DRGdQqX82h.jpg",
            backdropPath: "/4HodYYKEIsGOdinkGi2Ucz6X9i0.jpg",
            voteAverage: 8.8,
            voteCount: 2400,
            releaseDateString: "2027-04-16",
            genreNames: ["Animation", "Action", "Sci-Fi"],
            runtimeMinutes: 140,
            tagline: "It's how you wear the mask.",
            certification: "PG",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "sbv1", name: "First Look", key: "cqGjhVJWtEg")],
            cast: [
                CastMember(id: 587506, name: "Shameik Moore", character: "Miles Morales (voice)"),
                CastMember(id: 54693, name: "Hailee Steinfeld", character: "Gwen Stacy (voice)"),
                CastMember(id: 1100, name: "Oscar Isaac", character: "Miguel O'Hara (voice)")
            ],
            logoPath: "/cmE0j3mQQe6xrzLryxGF9rF2KC8.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1003598,
            title: "Avengers: Secret Wars",
            mediaType: .movie,
            overview: "The grand conclusion to the Multiverse Saga brings the heroes of every reality together for the ultimate battle to preserve existence.",
            posterPath: "/f0YBuh4hyiAheXhh4JnJWoKi9g5.jpg",
            backdropPath: "/rytc6Lf4447C0CDncwFa4gxe0vY.jpg",
            voteAverage: 8.7,
            voteCount: 1950,
            releaseDateString: "2027-05-07",
            genreNames: ["Action", "Sci-Fi", "Adventure"],
            runtimeMinutes: 175,
            tagline: "The destiny of all worlds.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "asw1", name: "Teaser", key: "1pHDWnXmK7Y")],
            cast: [
                CastMember(id: 3223, name: "Robert Downey Jr.", character: "Victor von Doom"),
                CastMember(id: 71580, name: "Benedict Cumberbatch", character: "Doctor Strange")
            ],
            logoPath: "/6rfcehI0kmv2y8aGqKIYWENXO8y.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1300968,
            title: "The Hunger Games: Sunrise on the Reaping",
            mediaType: .movie,
            overview: "On the morning of the reaping for the 50th Annual Hunger Games, also known as the Second Quarter Quell, young Haymitch Abernathy is thrust into the deadly arena.",
            posterPath: "/ffJaYMtB6v1TrvkyhCOqwqCKm0o.jpg",
            backdropPath: "/aqFZcr2dxSZ2UwWSo1WC6C0rwDf.jpg",
            voteAverage: 8.3,
            voteCount: 750,
            releaseDateString: "2026-11-20",
            genreNames: ["Action", "Adventure", "Sci-Fi"],
            runtimeMinutes: 145,
            tagline: "Return to the Arena.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "hgsr1", name: "Teaser Announcement", key: "HGSR2026Teaser")],
            cast: [
                CastMember(id: 34567, name: "Tom Blyth", character: "Young Haymitch"),
                CastMember(id: 19492, name: "Jason Schwartzman", character: "Lucky Flickerman")
            ],
            logoPath: "/a3fhznw2K5WmDWFX7gf4AEBByRY.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1024604,
            title: "Frozen III",
            mediaType: .movie,
            overview: "Elsa and Anna embark on their most daunting journey yet beyond the enchanted forest to unravel the ancient origins of Arendelle's elemental magic.",
            posterPath: "/qzVuYNqRX7rBBuUdobS2SWEni5R.jpg",
            backdropPath: "/AsoITR3tq9PXk0j0VJyN7dkFkp9.jpg",
            voteAverage: 8.4,
            voteCount: 1200,
            releaseDateString: "2027-11-24",
            genreNames: ["Animation", "Family", "Adventure"],
            runtimeMinutes: 105,
            tagline: "Beyond the unknown.",
            certification: "PG",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "fz3_1", name: "D23 First Look", key: "FROZEN3D23Teaser")],
            cast: [
                CastMember(id: 8449, name: "Idina Menzel", character: "Elsa (voice)"),
                CastMember(id: 8450, name: "Kristen Bell", character: "Anna (voice)"),
                CastMember(id: 8452, name: "Josh Gad", character: "Olaf (voice)")
            ],
            logoPath: "/irfwoDMSoLUsY4KtnlzlpatCTxY.png",
            inCinemas: false
        ),
        MediaItem(
            id: 1078446,
            title: "Violent Night 2",
            mediaType: .movie,
            overview: "Santa Claus returns to defend another high-stakes holiday hostage crisis, bringing bone-crunching festive justice to a ruthless syndicate.",
            posterPath: "/7HPvgItDw9NgW3iy4tFRRuGNbuN.jpg",
            backdropPath: "/uvYnQE4I40J5vtj2acWYWSlv672.jpg",
            voteAverage: 7.8,
            voteCount: 620,
            releaseDateString: "2026-12-04",
            genreNames: ["Action", "Comedy", "Crime"],
            runtimeMinutes: 115,
            tagline: "Naughty list is closed.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "vn2_1", name: "Red Band Teaser", key: "VN2TeaserOfficial")],
            cast: [
                CastMember(id: 3594, name: "David Harbour", character: "Santa Claus"),
                CastMember(id: 54321, name: "Beverly D'Angelo", character: "Gertrude")
            ],
            logoPath: "/pSgertcFBwVeF9ihdfhdbHueekz.png",
            inCinemas: false
        )
    ]
}
