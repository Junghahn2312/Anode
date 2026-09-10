import Foundation

public struct TVSeason: Identifiable, Codable, Hashable {
    public let id: Int
    public let seasonNumber: Int
    public let name: String
    public let episodeCount: Int
    public let posterPath: String?
    
    public init(id: Int, seasonNumber: Int, name: String, episodeCount: Int, posterPath: String? = nil) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.name = name
        self.episodeCount = episodeCount
        self.posterPath = posterPath
    }
}

public struct TVEpisode: Identifiable, Codable, Hashable {
    public let id: Int
    public let episodeNumber: Int
    public let seasonNumber: Int
    public let name: String
    public let overview: String
    public let runtime: Int?
    public let airDate: String?
    public let stillPath: String?
    public var isWatched: Bool
    
    public init(
        id: Int,
        episodeNumber: Int,
        seasonNumber: Int,
        name: String,
        overview: String,
        runtime: Int? = nil,
        airDate: String? = nil,
        stillPath: String? = nil,
        isWatched: Bool = false
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.name = name
        self.overview = overview
        self.runtime = runtime
        self.airDate = airDate
        self.stillPath = stillPath
        self.isWatched = isWatched
    }
    
    public func stillURL(size: String = "w780") -> URL? {
        guard let stillPath, !stillPath.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(stillPath)")
    }
    
    public var formattedRuntime: String {
        guard let runtime, runtime > 0 else { return "45 min" }
        return "\(runtime) min"
    }
    
    public var formattedAirDate: String {
        guard let airDate, !airDate.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: airDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return airDate
    }
}
