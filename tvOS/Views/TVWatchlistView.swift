import SwiftUI

public struct TVWatchlistView: View {
    @ObservedObject private var store = WatchlistStore.shared
    @State private var selectedFilter: WatchlistFilter = .all
    @State private var selectedItem: MediaItem?
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 36)
    ]
    
    public init() {}
    
    enum WatchlistFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case movies = "Movies"
        case tvShows = "TV Shows"
        case inCinemas = "In Cinemas"
        
        var id: String { rawValue }
    }
    
    private var filteredItems: [MediaItem] {
        store.records.map { $0.mediaItem }.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .movies:
                return item.mediaType == .movie
            case .tvShows:
                return item.mediaType == .tvShow
            case .inCinemas:
                return item.inCinemas
            }
        }
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 28) {
                // Header & Filter bar
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAVED DISCOVERIES")
                            .font(.system(size: 13, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("My List")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Filter Pills
                    if !store.records.isEmpty {
                        HStack(spacing: 16) {
                            ForEach(WatchlistFilter.allCases) { filter in
                                FilterPillButton(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 48)
                
                if store.records.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 56, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Your Watchlist is empty")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Add movies or television shows from Home, Cinema, or Streaming to keep track of what you want to watch.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 560)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 14) {
                        Text("No items found under \(selectedFilter.rawValue)")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(filteredItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    TVMediaCardView(item: item, width: 220)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
}

private struct FilterPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected || isFocused ? .white : .white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.25) : Color(white: 0.12))
                )
                .scaleEffect(isFocused ? 1.08 : 1.0)
                .shadow(
                    color: isFocused ? Color.black.opacity(0.7) : Color.clear,
                    radius: 12,
                    y: 4
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}
