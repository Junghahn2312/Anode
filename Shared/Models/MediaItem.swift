import Foundation

public struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let originalTitle: String?
    public let mediaType: MediaType
    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let voteAverage: Double
    public let voteCount: Int
    public let releaseDateString: String?
    public let genreNames: [String]
    public var runtimeMinutes: Int?
    public var tagline: String?
    public var certification: String?
    public var streamingProviders: [StreamingProvider]
    public var trailers: [VideoTrailer]
    public var cast: [CastMember]
    public var logoPath: String?
    public var rank: Int?
    public var availability: WatchAvailability?
    public var inCinemas: Bool
    
    public init(
        id: Int,
        title: String,
        originalTitle: String? = nil,
        mediaType: MediaType,
        overview: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double = 0.0,
        voteCount: Int = 0,
        releaseDateString: String? = nil,
        genreNames: [String] = [],
        runtimeMinutes: Int? = nil,
        tagline: String? = nil,
        certification: String? = nil,
        streamingProviders: [StreamingProvider] = [],
        trailers: [VideoTrailer] = [],
        cast: [CastMember] = [],
        logoPath: String? = nil,
        rank: Int? = nil,
        availability: WatchAvailability? = nil,
        inCinemas: Bool = false
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.mediaType = mediaType
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.releaseDateString = releaseDateString
        self.genreNames = genreNames
        self.runtimeMinutes = runtimeMinutes
        self.tagline = tagline
        self.certification = certification
        self.streamingProviders = streamingProviders
        self.trailers = trailers
        self.cast = cast
        self.logoPath = logoPath
        self.rank = rank
        self.availability = availability
        self.inCinemas = inCinemas
    }
    
    public var rating: Double {
        voteAverage
    }
    
    public var hasDigitalRelease: Bool {
        if !streamingProviders.isEmpty { return true }
        if let subs = availability?.subscriptions, !subs.isEmpty { return true }
        if let rent = availability?.rentOptions, !rent.isEmpty { return true }
        if let buy = availability?.buyOptions, !buy.isEmpty { return true }
        return false
    }
    
    public var isTheatricalExclusive: Bool {
        !hasDigitalRelease
    }
    
    public var releaseDateObject: Date? {
        guard let releaseDateString, !releaseDateString.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: releaseDateString)
    }
    
    public var isUpcomingTheatrical: Bool {
        guard let date = releaseDateObject else { return false }
        return date > Date() && isTheatricalExclusive
    }
    
    public var isNowPlayingTheatrical: Bool {
        guard let date = releaseDateObject else { return isTheatricalExclusive }
        return date <= Date() && isTheatricalExclusive
    }
    
    public var releaseDate: String? {
        releaseDateString
    }
    
    public var formattedTheatricalReleaseDate: String {
        guard let releaseDateString, !releaseDateString.isEmpty else { return "" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = inputFormatter.date(from: releaseDateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return releaseDateString
    }
    
    public var formattedRating: String {
        guard voteAverage > 0 else { return "NR" }
        return String(format: "%.1f", voteAverage)
    }
    
    public var yearString: String {
        guard let releaseDateString, releaseDateString.count >= 4 else { return "" }
        return String(releaseDateString.prefix(4))
    }
    
    public var formattedRuntime: String {
        guard let runtimeMinutes, runtimeMinutes > 0 else { return "" }
        let hours = runtimeMinutes / 60
        let minutes = runtimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    public func posterURL(size: String = "w500") -> URL? {
        guard let posterPath else { return nil }
        if posterPath.hasPrefix("http") { return URL(string: posterPath) }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(posterPath)")
    }
    
    public func backdropURL(size: String = "w1280") -> URL? {
        guard let backdropPath else { return nil }
        if backdropPath.hasPrefix("http") { return URL(string: backdropPath) }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(backdropPath)")
    }
    
    public func logoURL(size: String = "w500") -> URL? {
        guard let logoPath else { return nil }
        if logoPath.hasPrefix("http") { return URL(string: logoPath) }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(logoPath)")
    }
}
