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
                    if let logo = await fetchLogo(for: heroes[i]) {
                        heroes[i].logoPath = logo
                    }
                }
                memoryCache["hero_spotlights"] = heroes
                return heroes
            }
        }
        var fallback = Array((MockData.trendingItems + MockData.cinemaMovies).prefix(6))
        for i in 0..<fallback.count {
            if let logo = await fetchLogo(for: fallback[i]) {
                fallback[i].logoPath = logo
            }
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
        if let items = try? await getPagedMedia(endpoint: "/movie/now_playing", type: .movie), !items.isEmpty {
            let verified = await withTaskGroup(of: MediaItem?.self) { group in
                for item in items.prefix(15) {
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
            if !verified.isEmpty {
                let sorted = verified.sorted { ($0.releaseDateString ?? "") > ($1.releaseDateString ?? "") }
                memoryCache["in_cinemas"] = sorted
                return sorted
            }
        }
        var list = MockData.cinemaMovies.filter { $0.isNowPlayingTheatrical }
        for i in 0..<list.count {
            list[i].inCinemas = true
        }
        memoryCache["in_cinemas"] = list
        return list
    }
    
    public func fetchUpcomingCinemas() async -> [MediaItem] {
        if let cached = memoryCache["upcoming_cinemas"], !cached.isEmpty {
            return cached
        }
        if let items = try? await getPagedMedia(endpoint: "/movie/upcoming", type: .movie), !items.isEmpty {
            let verified = await withTaskGroup(of: MediaItem?.self) { group in
                for item in items.prefix(15) {
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
            if !verified.isEmpty {
                let sorted = verified.sorted { ($0.releaseDateString ?? "") < ($1.releaseDateString ?? "") }
                memoryCache["upcoming_cinemas"] = sorted
                return sorted
            }
        }
        let items = MockData.upcoming.filter { $0.isUpcomingTheatrical }
        memoryCache["upcoming_cinemas"] = items
        return items
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
            
            return MediaItem(
                id: id,
                title: title,
                originalTitle: dto.original_title ?? dto.original_name,
                mediaType: detectedType,
                overview: dto.overview ?? "",
                posterPath: dto.poster_path,
                backdropPath: dto.backdrop_path,
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
            subs = [.netflix, .primeVideo]
            rent = [PurchaseOption(providerName: "Apple TV", price: "$3.99")]
            buy = [PurchaseOption(providerName: "Apple TV", price: "$9.99")]
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
            id: 111,
            title: "Alien: Romulus",
            mediaType: .movie,
            overview: "While scavenging the deep ends of a derelict space station, a group of young space colonizers come face to face with the most terrifying life form in the universe.",
            posterPath: "/2uSWRTtCG336nuBiG8jOTEUKSy8.jpg",
            backdropPath: "/iYqSQaWDttQIQzsxg9xHyg0bttG.jpg",
            voteAverage: 8.2,
            voteCount: 3820,
            releaseDateString: "2026-08-16",
            genreNames: ["Horror", "Sci-Fi", "Thriller"],
            runtimeMinutes: 119,
            tagline: "In space, no one can hear you scream.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "ar1", name: "Official Trailer", key: "x0XDEhP4MQs")],
            cast: [
                CastMember(id: 41, name: "Cailee Spaeny", character: "Rain Carradine"),
                CastMember(id: 42, name: "David Jonsson", character: "Andy"),
                CastMember(id: 43, name: "Archie Renaux", character: "Tyler")
            ],
            logoPath: "/wb2OPyCSGLy7Ca5RquWF3VfOJKx.png",
            inCinemas: true
        ),
        MediaItem(
            id: 112,
            title: "Beetlejuice Beetlejuice",
            mediaType: .movie,
            overview: "After a family tragedy, three generations of the Deetz family return home to Winter River. Still haunted by Beetlejuice, Lydia's life is turned upside down when her teenage daughter opens the portal to the Afterlife.",
            posterPath: "/kKgQzkUCnQmeTPkyIwHly2t6ZFI.jpg",
            backdropPath: "/kF8ljC7Y4p1UsmKBi2LxelZpqw.jpg",
            voteAverage: 7.6,
            voteCount: 2940,
            releaseDateString: "2026-09-06",
            genreNames: ["Comedy", "Fantasy", "Horror"],
            runtimeMinutes: 105,
            tagline: "The juice is loose.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "bb1", name: "Official Trailer", key: "As-vKW4ZboI")],
            cast: [
                CastMember(id: 44, name: "Michael Keaton", character: "Beetlejuice"),
                CastMember(id: 45, name: "Winona Ryder", character: "Lydia Deetz"),
                CastMember(id: 46, name: "Jenna Ortega", character: "Astrid Deetz")
            ],
            logoPath: "/61Z6mL60ltShU393JkgBawAaeCw.png",
            inCinemas: true
        ),
        MediaItem(
            id: 113,
            title: "Deadpool & Wolverine",
            mediaType: .movie,
            overview: "A listless Wade Wilson toils away in civilian life with his days as the morally flexible mercenary Deadpool behind him. But when his homeworld faces an existential threat, Wade must reluctantly suit-up again with an even more reluctant Wolverine.",
            posterPath: "/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg",
            backdropPath: "/by8z9Fe8y7p4jo2YlW2SZDnptyT.jpg",
            voteAverage: 8.0,
            voteCount: 6540,
            releaseDateString: "2026-07-26",
            genreNames: ["Action", "Comedy", "Sci-Fi"],
            runtimeMinutes: 128,
            tagline: "Come together.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "dw1", name: "Official Trailer", key: "73_1biulkYk")],
            cast: [
                CastMember(id: 47, name: "Ryan Reynolds", character: "Wade Wilson / Deadpool"),
                CastMember(id: 48, name: "Hugh Jackman", character: "Logan / Wolverine"),
                CastMember(id: 49, name: "Emma Corrin", character: "Cassandra Nova")
            ],
            logoPath: "/2o48U3kMXGIqRAkKZQ3n5OTWSBy.png",
            inCinemas: true
        ),
        MediaItem(
            id: 115,
            title: "The Substance",
            mediaType: .movie,
            overview: "A fading celebrity decides to use a black-market drug, a cell-replicating substance that temporarily creates a younger, better version of herself.",
            posterPath: "/vhbQQdPnfLUxhdXhREITF5cYppT.jpg",
            backdropPath: "/bVSOgrxasVJF6V71T7v2KfBRSzu.jpg",
            voteAverage: 8.1,
            voteCount: 1950,
            releaseDateString: "2026-09-01",
            genreNames: ["Drama", "Horror", "Sci-Fi"],
            runtimeMinutes: 141,
            tagline: "Have you ever dreamt of a better version of yourself?",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "sub1", name: "Official Trailer", key: "LNlrGhPdnk8")],
            cast: [
                CastMember(id: 53, name: "Demi Moore", character: "Elisabeth Sparkle"),
                CastMember(id: 54, name: "Margaret Qualley", character: "Sue"),
                CastMember(id: 55, name: "Dennis Quaid", character: "Harvey")
            ],
            logoPath: "/1yw5B2rL7vneZq2RcWKqNVVjlOG.png",
            inCinemas: true
        ),
        MediaItem(
            id: 117,
            title: "The Wild Robot",
            mediaType: .movie,
            overview: "After a shipwreck, an intelligent robot called Roz is stranded on an uninhabited island. To survive the harsh environment, Roz bonds with the island's animals and cares for an orphaned baby goose.",
            posterPath: "/wTnV3PCVW5O92JMrFvvrRcV39RU.jpg",
            backdropPath: "/1pmXyN3sKeYoUhu5VBZiDU4BX21.jpg",
            voteAverage: 8.5,
            voteCount: 3100,
            releaseDateString: "2026-09-08",
            genreNames: ["Animation", "Sci-Fi", "Family"],
            runtimeMinutes: 102,
            tagline: "Discover your true nature.",
            certification: "PG",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "twr1", name: "Official Trailer", key: "67vbA5ZJb3k")],
            cast: [
                CastMember(id: 59, name: "Lupita Nyong'o", character: "Roz (voice)"),
                CastMember(id: 60, name: "Pedro Pascal", character: "Fink (voice)"),
                CastMember(id: 61, name: "Kit Connor", character: "Brightbill (voice)")
            ],
            logoPath: "/xvXJfGKjHHe1m4Usye198DCw7iJ.png",
            inCinemas: true
        )
    ]
    
    public static let freshFromTheatres: [MediaItem] = [
        MediaItem(
            id: 101,
            title: "Dune: Part Two",
            mediaType: .movie,
            overview: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family. Facing a choice between the love of his life and the fate of the known universe, he endeavors to prevent a terrible future only he can foresee.",
            posterPath: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
            backdropPath: "/xOMo8BRK7PfcJv9JCnx7s520Wio.jpg",
            voteAverage: 8.5,
            voteCount: 4620,
            releaseDateString: "2024-03-01",
            genreNames: ["Sci-Fi", "Adventure"],
            runtimeMinutes: 166,
            tagline: "Long live the fighters.",
            certification: "PG-13",
            streamingProviders: [.max],
            trailers: [VideoTrailer(id: "t1", name: "Official Trailer 3", key: "Way9Dexny3w")],
            cast: [
                CastMember(id: 1, name: "Timothée Chalamet", character: "Paul Atreides"),
                CastMember(id: 2, name: "Zendaya", character: "Chani"),
                CastMember(id: 3, name: "Rebecca Ferguson", character: "Lady Jessica"),
                CastMember(id: 4, name: "Javier Bardem", character: "Stilgar")
            ],
            inCinemas: false
        ),
        MediaItem(
            id: 103,
            title: "Civil War",
            mediaType: .movie,
            overview: "In a near-future dystopian America, a team of military-embedded journalists races across the country to reach Washington, D.C. before rebel factions descend upon the White House.",
            posterPath: "/sh7Rg8Er3tFcN9BpKIPOMvALgZd.jpg",
            backdropPath: "/z121mtTxg5v9whDjy9spvBjeTeO.jpg",
            voteAverage: 7.4,
            voteCount: 2150,
            releaseDateString: "2024-04-12",
            genreNames: ["Action", "Thriller", "Drama"],
            runtimeMinutes: 109,
            tagline: "Welcome to the frontlines.",
            certification: "R",
            streamingProviders: [.max],
            trailers: [VideoTrailer(id: "t3", name: "Official Trailer", key: "aDyQxtg0V2w")],
            cast: [
                CastMember(id: 9, name: "Kirsten Dunst", character: "Lee Smith"),
                CastMember(id: 10, name: "Wagner Moura", character: "Joel"),
                CastMember(id: 11, name: "Cailee Spaeny", character: "Jessie")
            ],
            inCinemas: false
        ),
        MediaItem(
            id: 104,
            title: "Furiosa: A Mad Max Saga",
            mediaType: .movie,
            overview: "As the world fell, young Furiosa is snatched from the Green Place of Many Mothers and falls into the hands of a great Biker Horde led by the Warlord Dementus.",
            posterPath: "/iADOJ8Zymht2JPMoy3R7xceZprc.jpg",
            backdropPath: "/wNAhuOZ3Zf84jCIpkRw8vFaEN8i.jpg",
            voteAverage: 7.8,
            voteCount: 3100,
            releaseDateString: "2024-05-24",
            genreNames: ["Action", "Sci-Fi", "Adventure"],
            runtimeMinutes: 148,
            tagline: "Out of the Wasteland.",
            certification: "R",
            streamingProviders: [.max],
            trailers: [VideoTrailer(id: "t4", name: "Official Trailer", key: "XJMuhwVlca4")],
            cast: [
                CastMember(id: 12, name: "Anya Taylor-Joy", character: "Imperator Furiosa"),
                CastMember(id: 13, name: "Chris Hemsworth", character: "Warlord Dementus")
            ],
            inCinemas: false
        ),
        MediaItem(
            id: 102,
            title: "Oppenheimer",
            mediaType: .movie,
            overview: "The story of J. Robert Oppenheimer's role in the development of the atomic bomb during World War II, examining the theoretical physicist's turbulent genius and the catastrophic ethical weight of scientific achievement.",
            posterPath: "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
            backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
            voteAverage: 8.9,
            voteCount: 7890,
            releaseDateString: "2023-07-21",
            genreNames: ["Drama", "History"],
            runtimeMinutes: 180,
            tagline: "The world forever changes.",
            certification: "R",
            streamingProviders: [.primeVideo],
            trailers: [VideoTrailer(id: "t2", name: "Main Trailer", key: "uYPbbksJxIg")],
            cast: [
                CastMember(id: 5, name: "Cillian Murphy", character: "J. Robert Oppenheimer"),
                CastMember(id: 6, name: "Emily Blunt", character: "Katherine Oppenheimer"),
                CastMember(id: 7, name: "Matt Damon", character: "Leslie Groves"),
                CastMember(id: 8, name: "Robert Downey Jr.", character: "Lewis Strauss")
            ],
            inCinemas: false
        )
    ]
    
    public static let trendingItems: [MediaItem] = [
        MediaItem(
            id: 201,
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
            id: 202,
            title: "Slow Horses",
            mediaType: .tvShow,
            overview: "This quick-witted espionage drama follows a dysfunctional team of MI5 agents—and their obnoxious boss, the notorious Jackson Lamb—as they navigate the espionage world's smoke and mirrors to defend England from sinister forces.",
            posterPath: "/1g1eT3Kw8C57AnQdZIcLyRU4xkw.jpg",
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
            id: 203,
            title: "The Penguin",
            mediaType: .tvShow,
            overview: "Following the events of The Batman, Oswald Cobblepot begins his ruthless climb to seize control of Gotham City's criminal underworld as an all-out turf war brews.",
            posterPath: "/u7xqyWcJXL0LejV6PQrkYPQbfD2.jpg",
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
            id: 204,
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
                id: 301,
                title: "Ripley",
                mediaType: .tvShow,
                overview: "A grifter drawn into a world of wealth and privilege after taking a unique job in Italy finds himself entangled in a complex web of deception, fraud, and murder.",
                posterPath: "/zU0htwkhNvBQdVSIKB9s6hgVeFK.jpg",
                backdropPath: "/3s2j9u82L4x6Z9V5z0e7Q1r3w.jpg",
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
                id: 302,
                title: "Baby Reindeer",
                mediaType: .tvShow,
                overview: "When a struggling comedian shows one kind gesture to a vulnerable woman, an obsessive stalking nightmare erupts that forces both to confront deeply buried trauma.",
                posterPath: "/pylL2yER1E23rq60imU9GVYusxu.jpg",
                backdropPath: "/z121mtTxg5v9whDjy9spvBjeTeO.jpg",
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
                id: 303,
                title: "Glass Onion: A Knives Out Mystery",
                mediaType: .movie,
                overview: "World-famous detective Benoit Blanc heads to Greece to peel back the layers of a mystery surrounding a tech billionaire and his eclectic crew of friends.",
                posterPath: "/vDGr1YdrlfbU9wxTOdpf3zChmv9.jpg",
                backdropPath: "/dKqa850uvbNSCaQCV4Im1XlzEtQ.jpg",
                voteAverage: 7.5,
                voteCount: 5400,
                releaseDateString: "2022-12-23",
                genreNames: ["Comedy", "Mystery", "Thriller"],
                runtimeMinutes: 139,
                tagline: "You can't solve it alone.",
                certification: "PG-13",
                streamingProviders: [.netflix]
            ),
            MediaItem(
                id: 304,
                title: "The Killer",
                mediaType: .movie,
                overview: "After a fateful near-miss, an assassin battles his employers, and himself, on an international manhunt he insists isn't personal.",
                posterPath: "/e7J69KVLueQfliVvKvyEZWjhAw.jpg",
                backdropPath: "/bSqpOsrhQIenDoGq6w893Y8n8lr.jpg",
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
                id: 305,
                title: "Society of the Snow",
                mediaType: .movie,
                overview: "In 1972, a Uruguayan rugby team's flight crashes onto a glacier in the heart of the Andes, where survivors must resort to extreme measures to stay alive.",
                posterPath: "/2e853FDVSIso600RqCuOp003Q9y.jpg",
                backdropPath: "/tLscOARAybtDUBIrIKVoF3BTSRk.jpg",
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
                id: 306,
                title: "Stranger Things",
                mediaType: .tvShow,
                overview: "When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces and one strange little girl.",
                posterPath: "/49WJfeN0moxb9IPfGn8AIqMGskD.jpg",
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
                id: 311,
                title: "Killers of the Flower Moon",
                mediaType: .movie,
                overview: "When oil is discovered in 1920s Oklahoma under Osage Nation land, the Osage people are murdered one by one until the FBI steps in to unravel the conspiracy.",
                posterPath: "/dB6Krk806zeqd0YNp2ngQ9zXteH.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.9,
                voteCount: 3100,
                releaseDateString: "2023-10-20",
                genreNames: ["Crime", "Drama", "History"],
                runtimeMinutes: 206,
                tagline: "Can you spot the wolves in this picture?",
                certification: "R",
                streamingProviders: [.appleTV]
            ),
            MediaItem(
                id: 312,
                title: "Ted Lasso",
                mediaType: .tvShow,
                overview: "An American college football coach is hired to manage a struggling British soccer team, attempting to win over skeptical players and town with optimism.",
                posterPath: "/5fhZdwPmsDVJijDk879vdvZwugU.jpg",
                backdropPath: "/ixgFmf1X59PUZam2qbAfskx2gQr.jpg",
                voteAverage: 8.5,
                voteCount: 4100,
                releaseDateString: "2020-08-14",
                genreNames: ["Comedy", "Drama"],
                runtimeMinutes: 35,
                tagline: "Kindness makes a comeback.",
                certification: "TV-MA",
                streamingProviders: [.appleTV]
            ),
            MediaItem(
                id: 313,
                title: "CODA",
                mediaType: .movie,
                overview: "As a CODA (Child of Deaf Adults), Ruby is the only hearing person in her deaf family. When the family's fishing business is threatened, Ruby finds herself torn between pursuing her love of music and her fear of abandoning her parents.",
                posterPath: "/BzVjmm8SysUbh4niICj2vAncDq.jpg",
                backdropPath: "/dKqa850uvbNSCaQCV4Im1XlzEtQ.jpg",
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
                id: 314,
                title: "Silo",
                mediaType: .tvShow,
                overview: "In a ruined and toxic future, thousands live in a giant underground silo. When its sheriff breaks a cardinal rule, an engineer uncovers shocking truths about their world.",
                posterPath: "/1N1s8ZzW3lU2Z13x8lq1q1p.jpg",
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
                id: 321,
                title: "The Mandalorian",
                mediaType: .tvShow,
                overview: "After the fall of the Galactic Empire, a lone gunfighter makes his way through the outer reaches of the lawless galaxy.",
                posterPath: "/eU1i6eHXlzMOlEq0ku1R07YmvEi.jpg",
                backdropPath: "/o7qi2v4uWQ8scZ1YW9Kbzy0vlAc.jpg",
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
                id: 322,
                title: "Loki",
                mediaType: .tvShow,
                overview: "After stealing the Tesseract during the events of Avengers: Endgame, an alternate version of Loki is brought to the mysterious Time Variance Authority.",
                posterPath: "/voHUmltYmKyle41993vt2Ggd1CP.jpg",
                backdropPath: "/a39c9U12kE8f80B0jHn5uE7rQ8L.jpg",
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
                id: 323,
                title: "Poor Things",
                mediaType: .movie,
                overview: "Brought back to life by an unorthodox scientist, a young woman runs off with a debauched lawyer on a whirlwind adventure across continents.",
                posterPath: "/kCGlIMHnOm8JPXq3rXM6c5wMxcT.jpg",
                backdropPath: "/bQS43HSLZzMjZkcHJz4fUg7f6wm.jpg",
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
                id: 324,
                title: "The Bear",
                mediaType: .tvShow,
                overview: "A young fine-dining chef comes home to Chicago to run his family Italian beef sandwich shop after a heartbreaking death in his family.",
                posterPath: "/sHFl7mhn1g5i7P2tL6fQW0a3mUo.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
                voteAverage: 8.6,
                voteCount: 3900,
                releaseDateString: "2022-06-23",
                genreNames: ["Drama", "Comedy"],
                runtimeMinutes: 30,
                tagline: "Every second counts.",
                certification: "TV-MA",
                streamingProviders: [.disneyPlus]
            )
        ],
        StreamingProvider.primeVideo.id: [
            MediaItem(
                id: 331,
                title: "The Boys",
                mediaType: .tvShow,
                overview: "A fun and irreverent take on what happens when superheroes abuse their superpowers rather than use them for good.",
                posterPath: "/7Ns6tO3aYjppI5bFhyYZurvBTup.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
                voteAverage: 8.5,
                voteCount: 9400,
                releaseDateString: "2019-07-26",
                genreNames: ["Action", "Sci-Fi", "Comedy"],
                runtimeMinutes: 60,
                tagline: "Never meet your heroes.",
                certification: "TV-MA",
                streamingProviders: [.primeVideo]
            ),
            MediaItem(
                id: 332,
                title: "Fallout",
                mediaType: .tvShow,
                overview: "In a future, post-apocalyptic Los Angeles brought about by nuclear decimation, citizens must live in underground bunkers to protect themselves from radiation, mutants and bandits.",
                posterPath: "/AnsSKR9LuK0T9bA0PFi3QQMlZw.jpg",
                backdropPath: "/3P52oz9HPcyfq5GwNuZYUHVoYes.jpg",
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
                id: 333,
                title: "The Idea of You",
                mediaType: .movie,
                overview: "Solène Marchand, a 40-year-old single mother, begins an unexpected romance with 24-year-old Hayes Campbell, the lead singer of August Moon, the hottest boy band on the planet.",
                posterPath: "/z121mtTxg5v9whDjy9spvBjeTeO.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.4,
                voteCount: 1600,
                releaseDateString: "2024-05-02",
                genreNames: ["Romance", "Comedy", "Drama"],
                runtimeMinutes: 115,
                tagline: "Age is just a number.",
                certification: "R",
                streamingProviders: [.primeVideo]
            ),
            MediaItem(
                id: 334,
                title: "Road House",
                mediaType: .movie,
                overview: "Ex-UFC fighter Dalton takes a job as a bouncer at a Florida Keys roadhouse, only to discover that this paradise is not all it seems.",
                posterPath: "/bXi6IQiCuHDvBh9YLG5dsXdPGio.jpg",
                backdropPath: "/oe7mWXYY8MAqJvOKIPdaACvd3o5.jpg",
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
                id: 335,
                title: "Reacher",
                mediaType: .tvShow,
                overview: "Jack Reacher, a veteran military police investigator, enters civilian life travelling from town to town across the United States.",
                posterPath: "/j73ytuz4015fGq2W1nK1E7k0fT5.jpg",
                backdropPath: "/gmecR22SuKqB8i4O1GqL0Kz9w.jpg",
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
                id: 341,
                title: "House of the Dragon",
                mediaType: .tvShow,
                overview: "The Targaryen dynasty is at the absolute apex of its power, with more than 15 dragons under their yoke. Most empires crumble from such heights.",
                posterPath: "/1X4h40fcB4WWUmIBK0auT4zRBAV.jpg",
                backdropPath: "/etjA2mG4V5zV6mO1O5wP4gQ3X9.jpg",
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
                id: 342,
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
                id: 351,
                title: "Yellowstone",
                mediaType: .tvShow,
                overview: "Follow the Dutton family, led by John Dutton, who controls the largest contiguous ranch in the United States, under constant attack by those it borders.",
                posterPath: "/peNC0eyc3TQJa6x4Td1IlRVUIpq.jpg",
                backdropPath: "/1G6mP6uL0U4wQ5L7R3n2y.jpg",
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
                id: 352,
                title: "Top Gun: Maverick",
                mediaType: .movie,
                overview: "After more than thirty years of service as one of the Navy’s top aviators, Pete Mitchell is where he belongs, pushing the envelope as a courageous test pilot.",
                posterPath: "/62HCnUTziyWcpDaBO2i1DX17ljH.jpg",
                backdropPath: "/odJ4hx6g6vBt4lBWKFD1tGLilAc.jpg",
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
                id: 353,
                title: "Tulsa King",
                mediaType: .tvShow,
                overview: "Just after he is released from prison after 25 years, New York mafia capo Dwight Manfredi is unceremoniously exiled by his boss to set up shop in Tulsa, Oklahoma.",
                posterPath: "/fwTv393FvDXlJp8zP9C5Q3K.jpg",
                backdropPath: "/7wP2gH0R9z8Y5vT1mK.jpg",
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
                id: 361,
                title: "Aftersun",
                mediaType: .movie,
                overview: "Sophie reflects on the shared joy and private melancholy of a holiday she took with her father twenty years earlier as memories fill the gaps between footage.",
                posterPath: "/4pukqLz0K4v0V0w7P9.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.8,
                voteCount: 1200,
                releaseDateString: "2022-10-21",
                genreNames: ["Drama"],
                runtimeMinutes: 102,
                tagline: "Memories that stay.",
                certification: "R",
                streamingProviders: [.mubi]
            ),
            MediaItem(
                id: 362,
                title: "Past Lives",
                mediaType: .movie,
                overview: "Nora and Hae Sung, two deeply connected childhood friends, are wrested apart after Nora's family emigrates from South Korea. Decades later, they are reunited.",
                posterPath: "/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
                voteAverage: 7.9,
                voteCount: 1900,
                releaseDateString: "2023-06-02",
                genreNames: ["Romance", "Drama"],
                runtimeMinutes: 106,
                tagline: "In-Yun: connected across lifetimes.",
                certification: "PG-13",
                streamingProviders: [.mubi]
            )
        ],
        StreamingProvider.crunchyroll.id: [
            MediaItem(
                id: 371,
                title: "Demon Slayer: Kimetsu no Yaiba",
                mediaType: .tvShow,
                overview: "It is the Taisho Period in Japan. Tanjiro, a kindhearted boy who sells charcoal for a living, finds his family slaughtered by a demon.",
                posterPath: "/xUfRZu2mi8jH69hmV1cr5F1LGDl.jpg",
                backdropPath: "/nTvM4mhqZlHIUQRLxqPvLoooiWn.jpg",
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
                id: 372,
                title: "Jujutsu Kaisen",
                mediaType: .tvShow,
                overview: "Yuji Itadori is a boy with tremendous physical strength, though he lives a completely ordinary high school life. One day, to save a classmate, he eats the finger of Ryomen Sukuna.",
                posterPath: "/hFWScjl6vXnkWbYw0uQp8J9F4L.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
                voteAverage: 8.6,
                voteCount: 3800,
                releaseDateString: "2020-10-03",
                genreNames: ["Animation", "Action", "Supernatural"],
                runtimeMinutes: 24,
                tagline: "Embrace the curse.",
                certification: "TV-MA",
                streamingProviders: [.crunchyroll]
            )
        ],
        StreamingProvider.nowTV.id: [
            MediaItem(
                id: 381,
                title: "The Regime",
                mediaType: .tvShow,
                overview: "Follow the story of a modern European regime as it begins to unravel over the course of a year within the palace walls.",
                posterPath: "/z121mtTxg5v9whDjy9spvBjeTeO.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.2,
                voteCount: 420,
                releaseDateString: "2024-03-03",
                genreNames: ["Drama", "Comedy"],
                runtimeMinutes: 56,
                tagline: "All power fades.",
                certification: "TV-MA",
                streamingProviders: [.nowTV]
            ),
            MediaItem(
                id: 382,
                title: "Wonka",
                mediaType: .movie,
                overview: "Willy Wonka – chock-full of ideas and determined to change the world one delectable bite at a time – is determined to prove that the best things in life begin with a dream.",
                posterPath: "/qhb1qYHeY97Ol5zXO0Z0bQW9G.jpg",
                backdropPath: "/dKqa850uvbNSCaQCV4Im1XlzEtQ.jpg",
                voteAverage: 7.2,
                voteCount: 3100,
                releaseDateString: "2023-12-06",
                genreNames: ["Comedy", "Family", "Fantasy"],
                runtimeMinutes: 116,
                tagline: "Witness the origin.",
                certification: "PG",
                streamingProviders: [.nowTV]
            )
        ],
        StreamingProvider.bbcIPlayer.id: [
            MediaItem(
                id: 391,
                title: "Peaky Blinders",
                mediaType: .tvShow,
                overview: "A gangster family epic set in 1919 Birmingham, England and centered on a gang who sew razor blades in the peaks of their caps, and their fierce boss Tommy Shelby.",
                posterPath: "/vUUqzWa2LnHIVqkaKVlVGkVcZIW.jpg",
                backdropPath: "/w7Wp4z9Q0V3y1v.jpg",
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
                id: 392,
                title: "Happy Valley",
                mediaType: .tvShow,
                overview: "Catherine Cawood is a strong-willed police sergeant in West Yorkshire, still coming to terms with the suicide of her teenage daughter eight years earlier.",
                posterPath: "/7P4wQ9z1vK8y.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
                voteAverage: 8.4,
                voteCount: 1100,
                releaseDateString: "2014-04-29",
                genreNames: ["Crime", "Drama"],
                runtimeMinutes: 58,
                tagline: "Justice takes resilience.",
                certification: "TV-MA",
                streamingProviders: [.bbcIPlayer]
            )
        ],
        StreamingProvider.itvx.id: [
            MediaItem(
                id: 393,
                title: "Broadchurch",
                mediaType: .tvShow,
                overview: "The murder of a young boy in a small coastal town brings a media frenzy, which threatens to tear the community apart.",
                posterPath: "/1G6mP6uL0U4wQ5L7R3n2y.jpg",
                backdropPath: "/dKqa850uvbNSCaQCV4Im1XlzEtQ.jpg",
                voteAverage: 8.2,
                voteCount: 1600,
                releaseDateString: "2013-03-04",
                genreNames: ["Crime", "Drama", "Mystery"],
                runtimeMinutes: 48,
                tagline: "Secrets run deep.",
                certification: "TV-14",
                streamingProviders: [.itvx]
            ),
            MediaItem(
                id: 394,
                title: "The Duke",
                mediaType: .movie,
                overview: "In 1961, Kempton Bunton, a 60-year-old taxi driver, stole Goya's portrait of the Duke of Wellington from the National Gallery in London.",
                posterPath: "/z121mtTxg5v9whDjy9spvBjeTeO.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.2,
                voteCount: 450,
                releaseDateString: "2022-02-25",
                genreNames: ["Comedy", "Drama", "History"],
                runtimeMinutes: 96,
                tagline: "An extraordinarily true heist.",
                certification: "PG-13",
                streamingProviders: [.itvx]
            )
        ],
        StreamingProvider.channel4.id: [
            MediaItem(
                id: 395,
                title: "Derry Girls",
                mediaType: .tvShow,
                overview: "Amidst the political conflict of Northern Ireland in the 1990s, five high school friends navigate the universal challenges of being a teenager.",
                posterPath: "/4pukqLz0K4v0V0w7P9.jpg",
                backdropPath: "/2meX1nMdScFOoV4370rqHWFDxZ2.jpg",
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
                id: 396,
                title: "It's A Sin",
                mediaType: .tvShow,
                overview: "A chronicle of four friends during a decade in which everything changed, including the rise of AIDS in 1980s London.",
                posterPath: "/7P4wQ9z1vK8y.jpg",
                backdropPath: "/dKqa850uvbNSCaQCV4Im1XlzEtQ.jpg",
                voteAverage: 8.5,
                voteCount: 950,
                releaseDateString: "2021-01-22",
                genreNames: ["Drama"],
                runtimeMinutes: 48,
                tagline: "Remember the days.",
                certification: "TV-MA",
                streamingProviders: [.channel4]
            )
        ],
        StreamingProvider.skyGo.id: [
            MediaItem(
                id: 397,
                title: "Gangs of London",
                mediaType: .tvShow,
                overview: "When the head of a criminal organization is assassinated, the sudden power vacuum creates a battle between rival gangs on the streets of London.",
                posterPath: "/1G6mP6uL0U4wQ5L7R3n2y.jpg",
                backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                voteAverage: 7.9,
                voteCount: 880,
                releaseDateString: "2020-04-23",
                genreNames: ["Action", "Crime", "Drama"],
                runtimeMinutes: 58,
                tagline: "Blood runs the city.",
                certification: "TV-MA",
                streamingProviders: [.skyGo]
            ),
            MediaItem(
                id: 398,
                title: "The Beekeeper",
                mediaType: .movie,
                overview: "One man's brutal campaign for vengeance takes on national stakes after he is revealed to be a former operative of a powerful and clandestine organization.",
                posterPath: "/A7EByudX0eOzlkQ2FIbogzyazm2.jpg",
                backdropPath: "/4woSOUD0equCwXLwh2jiJD2q26S.jpg",
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
            id: 401,
            title: "The Godfather",
            mediaType: .movie,
            overview: "Spanning the years 1945 to 1955, a chronicle of the fictional Italian-American Corleone crime family. When organized crime family patriarch, Vito Corleone, barely survives an attempt on his life, his youngest son, Michael, steps in to take care of the would-be killers.",
            posterPath: "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
            backdropPath: "/tmU7GeKVybMWF9YdfZveL75z5Un.jpg",
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
            id: 402,
            title: "Interstellar",
            mediaType: .movie,
            overview: "The adventures of a group of explorers who make use of a newly discovered wormhole to surpass the limitations on human space travel and conquer the vast distances involved in an interstellar voyage.",
            posterPath: "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
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
            id: 403,
            title: "Spirited Away",
            mediaType: .movie,
            overview: "A young girl, Chihiro, becomes trapped in a strange new world of spirits. When her parents undergo a mysterious transformation, she must call upon the courage she never knew she had to free her family.",
            posterPath: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
            backdropPath: "/Ab8mkHmkYADjU7wQiOkia99GQI.jpg",
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
            id: 501,
            title: "Gladiator II",
            mediaType: .movie,
            overview: "Years after witnessing the death of the revered hero Maximus at the hands of his uncle, Lucius must enter the Colosseum after his home is conquered by the tyrannical Emperors who now lead Rome with an iron fist.",
            posterPath: "/2cxhvwyEwRlysAmRH4iodkvo0z5.jpg",
            backdropPath: "/tOqIwliWMovSIZ9DyvHcHI7p2im.jpg",
            voteAverage: 7.6,
            voteCount: 1840,
            releaseDateString: "2026-11-20",
            genreNames: ["Action", "Adventure", "Drama"],
            runtimeMinutes: 148,
            tagline: "What we do in life echoes in eternity.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "t9", name: "Official Trailer", key: "4rgYUipGJNo")],
            logoPath: "/jwXk1c2esVoEzVLplPiQubNVyFC.png",
            inCinemas: false
        ),
        MediaItem(
            id: 502,
            title: "Nosferatu",
            mediaType: .movie,
            overview: "A gothic tale of obsession between a haunted young woman in 19th-century Germany and the ancient Transylvanian vampire who stalks her, bringing untold horror in his wake.",
            posterPath: "/5qGIxdEO841C0tdY8vOdLoRVrr0.jpg",
            backdropPath: "/gprjiZWY43vxSKngMha1wfb5TGG.jpg",
            voteAverage: 7.9,
            voteCount: 1200,
            releaseDateString: "2026-12-25",
            genreNames: ["Horror", "Drama", "Fantasy"],
            runtimeMinutes: 132,
            tagline: "He is coming.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "t10", name: "Official Trailer", key: "dG91B3hHyY4")],
            logoPath: "/pkAiCBNf5uDpqT2rCDmatRyhDiK.png",
            inCinemas: false
        ),
        MediaItem(
            id: 503,
            title: "Mission: Impossible - The Final Reckoning",
            mediaType: .movie,
            overview: "Ethan Hunt and his IMF team face their greatest adversary yet as they race to stop an apocalyptic artificial intelligence threat known as the Entity before it reshapes global destiny.",
            posterPath: "/iKPsC9EFUafRP9SrUznI61getVP.jpg",
            backdropPath: "/538U9snNc2fpnOmYXAPUh3zn31H.jpg",
            voteAverage: 8.3,
            voteCount: 950,
            releaseDateString: "2027-05-23",
            genreNames: ["Action", "Adventure", "Thriller"],
            runtimeMinutes: 165,
            tagline: "Our lives are the sum of our choices.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "t11", name: "Teaser Trailer", key: "NOhDyZJ_318")],
            logoPath: "/7yXEfWFDGpqIfq9wdpMOHcHbi8g.png",
            inCinemas: false
        ),
        MediaItem(
            id: 504,
            title: "Captain America: Brave New World",
            mediaType: .movie,
            overview: "Sam Wilson finds himself in the middle of an international incident after meeting with newly elected U.S. President Thaddeus Ross, uncovering a nefarious global plot.",
            posterPath: "/pzIddUEMWhWzfvLI3TwxUG2wGoi.jpg",
            backdropPath: "/ce3prrjh9ZehEl5JinNqr4jIeaB.jpg",
            voteAverage: 7.8,
            voteCount: 880,
            releaseDateString: "2027-02-14",
            genreNames: ["Action", "Sci-Fi", "Adventure"],
            runtimeMinutes: 125,
            tagline: "A new world order.",
            certification: "PG-13",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "t12", name: "Official Trailer", key: "1pHDWnXmK7Y")],
            logoPath: "/ubZE4IVOdOnZIp6mapDGooDYeJh.png",
            inCinemas: false
        ),
        MediaItem(
            id: 505,
            title: "Wicked",
            mediaType: .movie,
            overview: "The untold story of the witches of Oz stars Cynthia Erivo as Elphaba and Ariana Grande as Glinda.",
            posterPath: "/xDGbZ0JJ3mYaGKy4Nzd9Kph6M9L.jpg",
            backdropPath: "/beuMhwEdoMpJhyoZiCldogaqsKI.jpg",
            voteAverage: 7.8,
            voteCount: 1680,
            releaseDateString: "2026-11-27",
            genreNames: ["Drama", "Fantasy", "Music"],
            runtimeMinutes: 160,
            tagline: "Everyone deserves the chance to fly.",
            certification: "PG",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "wk1", name: "Official Trailer", key: "6COmYeLsz4c")],
            logoPath: "/oeSUu0CjuohGO6oIiFkxn4xHbrt.png",
            inCinemas: false
        ),
        MediaItem(
            id: 506,
            title: "Smile 2",
            mediaType: .movie,
            overview: "Global pop sensation Skye Riley begins experiencing increasingly terrifying and inexplicable events.",
            posterPath: "/ht8Uv9QPv9y7K0RvUyJIaXOZTfd.jpg",
            backdropPath: "/iR79ciqhtaZ9BE7YFA1HpCHQgX4.jpg",
            voteAverage: 7.4,
            voteCount: 1430,
            releaseDateString: "2026-10-23",
            genreNames: ["Horror", "Mystery"],
            runtimeMinutes: 127,
            tagline: "It will never let you go.",
            certification: "R",
            streamingProviders: [],
            trailers: [VideoTrailer(id: "s2", name: "Official Trailer", key: "0HY6QFlBzUY")],
            logoPath: "/tOyHVKbXcSTXfF5XH1odzJQiq7l.png",
            inCinemas: false
        )
    ]
}
