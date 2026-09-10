import Foundation

public actor TMDBService {
    public static let shared = TMDBService()
    
    private let baseURL = "https://api.themoviedb.org/3"
    private var apiKey: String?
    
    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    public func setAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    // MARK: - API Calls with Curated Fallback
    
    public func fetchCinemaMovies() async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            if let items = try? await getPagedMedia(endpoint: "/movie/now_playing", type: .movie) {
                return items
            }
        }
        return MockData.cinemaMovies
    }
    
    public func fetchTrending() async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            if let items = try? await getPagedMedia(endpoint: "/trending/all/week", type: .movie) {
                return items
            }
        }
        return MockData.trendingItems
    }
    
    public func fetchStreaming(provider: StreamingProvider) async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            let endpoint = "/discover/movie?with_watch_providers=\(provider.id)&watch_region=US&sort_by=popularity.desc"
            if let items = try? await getPagedMedia(endpoint: endpoint, type: .movie) {
                return items
            }
        }
        return MockData.streamingCatalog[provider.id] ?? MockData.trendingItems
    }
    
    public func fetchNewReleases() async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            if let items = try? await getPagedMedia(endpoint: "/movie/now_playing?sort_by=primary_release_date.desc", type: .movie) {
                return items
            }
        }
        return MockData.newReleases
    }
    
    public func fetchTopRated() async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            if let items = try? await getPagedMedia(endpoint: "/movie/top_rated", type: .movie) {
                return items
            }
        }
        return MockData.topRated
    }
    
    public func fetchUpcoming() async -> [MediaItem] {
        if let apiKey, !apiKey.isEmpty {
            if let items = try? await getPagedMedia(endpoint: "/movie/upcoming", type: .movie) {
                return items
            }
        }
        return MockData.upcoming
    }
    
    public func search(query: String) async -> [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        if let apiKey, !apiKey.isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            if let items = try? await getPagedMedia(endpoint: "/search/multi?query=\(encoded)", type: .movie) {
                return items
            }
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
    
    // MARK: - Network Helper
    
    private func getPagedMedia(endpoint: String, type: MediaType) async throws -> [MediaItem] {
        guard let apiKey else { return [] }
        let separator = endpoint.contains("?") ? "&" : "?"
        guard let url = URL(string: "\(baseURL)\(endpoint)\(separator)api_key=\(apiKey)") else { return [] }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let decoded = try JSONDecoder().decode(TMDBPagedResponse.self, from: data)
        return decoded.results.map { dto in
            let detectedType = dto.media_type == "tv" ? MediaType.tvShow : type
            return MediaItem(
                id: dto.id,
                title: dto.title ?? dto.name ?? "Untitled",
                originalTitle: dto.original_title ?? dto.original_name,
                mediaType: detectedType,
                overview: dto.overview ?? "",
                posterPath: dto.poster_path,
                backdropPath: dto.backdrop_path,
                voteAverage: dto.vote_average ?? 0.0,
                voteCount: dto.vote_count ?? 0,
                releaseDateString: dto.release_date ?? dto.first_air_date,
                genreNames: []
            )
        }
    }
}

// MARK: - DTO Decoders

private struct TMDBPagedResponse: Codable {
    let page: Int?
    let results: [TMDBMediaDTO]
}

private struct TMDBMediaDTO: Codable {
    let id: Int
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
}

// MARK: - Rich Curated Mock Data (Zero Emojis)

public enum MockData {
    public static let cinemaMovies: [MediaItem] = [
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
            ]
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
            ]
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
            ]
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
            ]
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
            )
        ],
        StreamingProvider.appleTV.id: [
            trendingItems[0], // Severance
            trendingItems[1]  // Slow Horses
        ],
        StreamingProvider.disneyPlus.id: [
            trendingItems[3] // Shogun
        ],
        StreamingProvider.primeVideo.id: [
            cinemaMovies[1] // Oppenheimer
        ],
        StreamingProvider.max.id: [
            cinemaMovies[0], // Dune 2
            trendingItems[2] // The Penguin
        ]
    ]
    
    public static let newReleases: [MediaItem] = [
        cinemaMovies[0],
        cinemaMovies[2],
        cinemaMovies[3],
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
            backdropPath: "/euYIwmwkmz95mnXvufEmbL6ovhA.jpg",
            voteAverage: 7.6,
            voteCount: 1840,
            releaseDateString: "2024-11-22",
            genreNames: ["Action", "Adventure", "Drama"],
            runtimeMinutes: 148,
            tagline: "What we do in life echoes in eternity.",
            certification: "R",
            trailers: [VideoTrailer(id: "t9", name: "Official Trailer", key: "4rgYUipGJNo")]
        ),
        MediaItem(
            id: 502,
            title: "Nosferatu",
            mediaType: .movie,
            overview: "A gothic tale of obsession between a haunted young woman in 19th-century Germany and the ancient Transylvanian vampire who stalks her, bringing untold horror in his wake.",
            posterPath: "/5qGIxdEO841C0tdY8vOdLoRVrr0.jpg",
            backdropPath: "/4c4k2j9u82L4x6Z9V5z0e7Q1r3w.jpg",
            voteAverage: 7.9,
            voteCount: 1200,
            releaseDateString: "2024-12-25",
            genreNames: ["Horror", "Drama", "Fantasy"],
            runtimeMinutes: 132,
            tagline: "He is coming.",
            certification: "R",
            trailers: [VideoTrailer(id: "t10", name: "Official Trailer", key: "dG91B3hHyY4")]
        )
    ]
}
