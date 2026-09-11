import Foundation

public actor TraktService {
    public static let shared = TraktService()
    
    private let baseURL = "https://api.trakt.tv"
    
    // Default or user-configured credentials
    private var clientId: String {
        get {
            UserDefaults.standard.string(forKey: "trakt_client_id") ?? "9d7e52a420b925b42d74fa191b35b6b5597b819f71c4c997cb658252a1a1f059"
        }
    }
    
    private var clientSecret: String {
        get {
            UserDefaults.standard.string(forKey: "trakt_client_secret") ?? ""
        }
    }
    
    private var accessToken: String? {
        get {
            UserDefaults.standard.string(forKey: "trakt_access_token")
        }
    }
    
    public init() {}
    
    // MARK: - Device Code OAuth Flow (Apple TV)
    
    public struct DeviceCodeResponse: Codable, Sendable {
        public let deviceCode: String
        public let userCode: String
        public let verificationUrl: String
        public let expiresIn: Int
        public let interval: Int
        
        enum CodingKeys: String, CodingKey {
            case deviceCode = "device_code"
            case userCode = "user_code"
            case verificationUrl = "verification_url"
            case expiresIn = "expires_in"
            case interval
        }
    }
    
    public struct TokenResponse: Codable, Sendable {
        public let accessToken: String
        public let tokenType: String
        public let expiresIn: Int
        public let refreshToken: String?
        public let scope: String?
        public let createdAt: Int
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case scope
            case createdAt = "created_at"
        }
    }
    
    public func requestDeviceCode() async throws -> DeviceCodeResponse {
        guard let url = URL(string: "\(baseURL)/oauth/device/code") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["client_id": clientId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }
    
    public func pollDeviceToken(deviceCode: String) async throws -> TokenResponse? {
        guard let url = URL(string: "\(baseURL)/oauth/device/token") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = [
            "code": deviceCode,
            "client_id": clientId
        ]
        if !clientSecret.isEmpty {
            body["client_secret"] = clientSecret
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        }
        
        // 400: authorization_pending / slow_down
        return nil
    }
    
    // MARK: - Playback Progress Sync
    
    public func fetchPlaybackProgress() async -> [ContinueWatchingItem] {
        guard let token = accessToken, !token.isEmpty else {
            return samplePlaybackItems()
        }
        
        guard let url = URL(string: "\(baseURL)/sync/playback") else {
            return samplePlaybackItems()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientId, forHTTPHeaderField: "trakt-api-key")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return samplePlaybackItems()
            }
            
            let decoded = try JSONDecoder().decode([TraktPlaybackDTO].self, from: data)
            var results: [ContinueWatchingItem] = []
            
            for dto in decoded {
                let progressDecimal = (dto.progress ?? 0.0) / 100.0
                if dto.type == "movie", let movie = dto.movie {
                    let tmdbId = movie.ids?.tmdb ?? dto.id
                    let title = movie.title ?? "Unknown Movie"
                    let yearStr = movie.year.map { String($0) }
                    
                    let media = MediaItem(
                        id: tmdbId,
                        title: title,
                        mediaType: .movie,
                        overview: "",
                        posterPath: nil,
                        backdropPath: nil,
                        releaseDateString: yearStr
                    )
                    
                    results.append(
                        ContinueWatchingItem(
                            id: "trakt-movie-\(dto.id)",
                            item: media,
                            progress: progressDecimal
                        )
                    )
                } else if dto.type == "episode", let episode = dto.episode, let show = dto.show {
                    let tmdbId = show.ids?.tmdb ?? dto.id
                    let showTitle = show.title ?? "Unknown Series"
                    let epTitle = episode.title
                    let seasonNum = episode.season
                    let epNum = episode.number
                    
                    let media = MediaItem(
                        id: tmdbId,
                        title: showTitle,
                        mediaType: .tvShow,
                        overview: "",
                        posterPath: nil,
                        backdropPath: nil
                    )
                    
                    results.append(
                        ContinueWatchingItem(
                            id: "trakt-ep-\(dto.id)",
                            item: media,
                            progress: progressDecimal,
                            episodeTitle: epTitle,
                            seasonNumber: seasonNum,
                            episodeNumber: epNum
                        )
                    )
                }
            }
            
            return results.isEmpty ? samplePlaybackItems() : results
        } catch {
            return samplePlaybackItems()
        }
    }
    
    // MARK: - Sample Continue Watching Items
    
    public func samplePlaybackItems() -> [ContinueWatchingItem] {
        return [
            ContinueWatchingItem(
                id: "cw-1",
                item: MediaItem(
                    id: 1108427,
                    title: "Moana",
                    mediaType: .movie,
                    overview: "Moana journeys across the vast ocean to save her island.",
                    posterPath: "/gaet1xQ2nxrG0V1Ep9T20ZMNEIC.jpg",
                    backdropPath: "/dmwb15BCkqjoXA9dXIsoY2Hn10F.jpg",
                    voteAverage: 8.1,
                    releaseDateString: "2026-11-27",
                    genreNames: ["Animation", "Adventure"],
                    runtimeMinutes: 107
                ),
                progress: 0.62
            ),
            ContinueWatchingItem(
                id: "cw-2",
                item: MediaItem(
                    id: 101,
                    title: "Dune: Part Two",
                    mediaType: .movie,
                    overview: "Paul Atreides unites with the Fremen while seeking revenge.",
                    posterPath: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
                    backdropPath: "/xOMo8BRK7PfcJv9JCnx7s520Wio.jpg",
                    voteAverage: 8.5,
                    releaseDateString: "2024-03-01",
                    genreNames: ["Sci-Fi", "Adventure"],
                    runtimeMinutes: 166
                ),
                progress: 0.44
            ),
            ContinueWatchingItem(
                id: "cw-3",
                item: MediaItem(
                    id: 201,
                    title: "Silo",
                    mediaType: .tvShow,
                    overview: "In a ruined and toxic future, thousands live in a giant underground silo.",
                    posterPath: "/1N1s8ZzW3lU2Z13x8lq1q1p.jpg",
                    backdropPath: "/1Qf5ClZJpmEPJgBqBB03UvCVXzO.jpg",
                    voteAverage: 8.3,
                    releaseDateString: "2023-05-05",
                    genreNames: ["Sci-Fi", "Drama"],
                    runtimeMinutes: 55
                ),
                progress: 0.78,
                episodeTitle: "The Order",
                seasonNumber: 2,
                episodeNumber: 4
            ),
            ContinueWatchingItem(
                id: "cw-4",
                item: MediaItem(
                    id: 202,
                    title: "Severance",
                    mediaType: .tvShow,
                    overview: "Mark leads a team of office workers whose memories have been surgically divided.",
                    posterPath: "/pUbtkYl8eQn28n8291f.jpg",
                    backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                    voteAverage: 8.7,
                    releaseDateString: "2022-02-18",
                    genreNames: ["Drama", "Mystery", "Sci-Fi"],
                    runtimeMinutes: 52
                ),
                progress: 0.35,
                episodeTitle: "The We We Are",
                seasonNumber: 1,
                episodeNumber: 9
            ),
            ContinueWatchingItem(
                id: "cw-5",
                item: MediaItem(
                    id: 102,
                    title: "Oppenheimer",
                    mediaType: .movie,
                    overview: "The story of J. Robert Oppenheimer's role in the development of the atomic bomb.",
                    posterPath: "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
                    backdropPath: "/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg",
                    voteAverage: 8.9,
                    releaseDateString: "2023-07-21",
                    genreNames: ["Drama", "History"],
                    runtimeMinutes: 180
                ),
                progress: 0.81
            )
        ]
    }
}

// MARK: - Trakt DTO Models

private struct TraktPlaybackDTO: Codable {
    let id: Int
    let progress: Double?
    let type: String?
    let movie: TraktMovieDTO?
    let episode: TraktEpisodeDTO?
    let show: TraktShowDTO?
}

private struct TraktMovieDTO: Codable {
    let title: String?
    let year: Int?
    let ids: TraktIdsDTO?
}

private struct TraktShowDTO: Codable {
    let title: String?
    let year: Int?
    let ids: TraktIdsDTO?
}

private struct TraktEpisodeDTO: Codable {
    let season: Int?
    let number: Int?
    let title: String?
    let ids: TraktIdsDTO?
}

private struct TraktIdsDTO: Codable {
    let trakt: Int?
    let slug: String?
    let tmdb: Int?
    let imdb: String?
}
