import Foundation

public struct WatchlistRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let mediaItem: MediaItem
    public let addedAt: Date
    public var isWatched: Bool
    public var userRating: Int?
    public var notes: String?
    
    public init(
        mediaItem: MediaItem,
        addedAt: Date = Date(),
        isWatched: Bool = false,
        userRating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = mediaItem.id
        self.mediaItem = mediaItem
        self.addedAt = addedAt
        self.isWatched = isWatched
        self.userRating = userRating
        self.notes = notes
    }
}
