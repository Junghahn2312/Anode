import Foundation

public struct ContinueWatchingItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let item: MediaItem
    public let progress: Double
    public let lastWatchedDate: Date?
    public let episodeTitle: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    
    public init(
        id: String,
        item: MediaItem,
        progress: Double,
        lastWatchedDate: Date? = nil,
        episodeTitle: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) {
        self.id = id
        self.item = item
        self.progress = max(0.0, min(1.0, progress))
        self.lastWatchedDate = lastWatchedDate
        self.episodeTitle = episodeTitle
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }
    
    public var formattedProgress: String {
        if let s = seasonNumber, let e = episodeNumber {
            let epPrefix = "S\(s) E\(e)"
            if let mins = remainingMinutes, mins > 0 {
                return "\(epPrefix) • \(mins)m left"
            }
            return epPrefix
        }
        
        if let mins = remainingMinutes, mins > 0 {
            return "\(mins)m left"
        }
        
        let percent = Int(progress * 100)
        return "\(percent)% watched"
    }
    
    public var remainingMinutes: Int? {
        guard let total = item.runtimeMinutes, total > 0 else { return nil }
        let remaining = Double(total) * (1.0 - progress)
        return max(1, Int(remaining.rounded()))
    }
}

extension Array where Element == ContinueWatchingItem {
    public func deduplicated() -> [ContinueWatchingItem] {
        var seen = Set<String>()
        return filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }
}

