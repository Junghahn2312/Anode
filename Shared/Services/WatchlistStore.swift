import Foundation
import Combine

@MainActor
public final class WatchlistStore: ObservableObject {
    public static let shared = WatchlistStore()
    
    @Published public private(set) var records: [WatchlistRecord] = []
    
    private let fileURL: URL
    
    public init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDir = paths.first ?? FileManager.default.temporaryDirectory
        self.fileURL = docDir.appendingPathComponent("anode_watchlist.json")
        load()
    }
    
    public func contains(id: Int) -> Bool {
        records.contains(where: { $0.id == id })
    }
    
    public func toggleWatchlist(item: MediaItem) {
        if let index = records.firstIndex(where: { $0.id == item.id }) {
            records.remove(at: index)
        } else {
            let record = WatchlistRecord(mediaItem: item)
            records.insert(record, at: 0)
        }
        save()
    }
    
    public func toggleWatched(id: Int) {
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index].isWatched.toggle()
            save()
        }
    }
    
    public func remove(id: Int) {
        records.removeAll(where: { $0.id == id })
        save()
    }
    
    public var items: [MediaItem] {
        records.map(\.mediaItem)
    }
    
    public func clear() {
        records.removeAll()
        save()
    }
    
    public var unwatchedItems: [MediaItem] {
        records.filter { !$0.isWatched }.map(\.mediaItem)
    }
    
    public var watchedItems: [MediaItem] {
        records.filter { $0.isWatched }.map(\.mediaItem)
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            self.records = try JSONDecoder().decode([WatchlistRecord].self, from: data)
        } catch {
            print("Failed to load watchlist: \(error)")
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save watchlist: \(error)")
        }
    }
}
