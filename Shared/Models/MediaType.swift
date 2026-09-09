import Foundation

public enum MediaType: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie = "movie"
    case tvShow = "tv"
    
    public var id: String { rawValue }
    
    public var displayTitle: String {
        switch self {
        case .movie: return "Movie"
        case .tvShow: return "TV Series"
        }
    }
    
    public var sfSymbolName: String {
        switch self {
        case .movie: return "film"
        case .tvShow: return "tv"
        }
    }
}
