import Foundation

public struct VideoTrailer: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let key: String
    public let site: String
    public let type: String
    public let isOfficial: Bool
    
    public init(
        id: String,
        name: String,
        key: String,
        site: String = "YouTube",
        type: String = "Trailer",
        isOfficial: Bool = true
    ) {
        self.id = id
        self.name = name
        self.key = key
        self.site = site
        self.type = type
        self.isOfficial = isOfficial
    }
    
    public var youtubeURL: URL? {
        guard site.lowercased() == "youtube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
    
    public var youtubeThumbnailURL: URL? {
        guard site.lowercased() == "youtube" else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg")
    }
}
