import SwiftUI

public struct WatchlistView: View {
    @ObservedObject private var store = WatchlistStore.shared
    @State private var filterState: WatchlistFilter = .toWatch
    @State private var selectedItem: MediaItem?
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public enum WatchlistFilter: String, CaseIterable {
        case toWatch = "To Watch"
        case watched = "Watched"
        case all = "All"
    }
    
    public init() {}
    
    private var displayedRecords: [WatchlistRecord] {
        switch filterState {
        case .toWatch:
            return store.records.filter { !$0.isWatched }
        case .watched:
            return store.records.filter { $0.isWatched }
        case .all:
            return store.records
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANODE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Watchlist")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Segmented Filter
                Picker("Filter", selection: $filterState) {
                    ForEach(WatchlistFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                if displayedRecords.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(.white.opacity(0.2))
                        
                        Text("Your Watchlist is empty")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Tap + Watchlist on any movie or TV series to keep track of what you want to watch.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(displayedRecords) { record in
                                Button {
                                    selectedItem = record.mediaItem
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        PosterCardView(item: record.mediaItem, width: 160)
                                        
                                        // Watched badge
                                        Button {
                                            store.toggleWatched(id: record.id)
                                        } label: {
                                            Image(systemName: record.isWatched ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(record.isWatched ? .white : .white.opacity(0.4))
                                                .padding(8)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        store.toggleWatched(id: record.id)
                                    } label: {
                                        if record.isWatched {
                                            Label("Mark as Unwatched", systemImage: "circle")
                                        } else {
                                            Label("Mark as Watched", systemImage: "checkmark.circle")
                                        }
                                    }
                                    
                                    Button(role: .destructive) {
                                        store.remove(id: record.id)
                                    } label: {
                                        Label("Remove from Watchlist", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(item: $selectedItem) { item in
                MediaDetailView(item: item)
            }
        }
    }
}
