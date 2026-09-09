import SwiftUI

public struct SearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = ""
    @State private var selectedFilter: String = "All"
    @State private var selectedItem: MediaItem?
    
    private let filters = ["All", "Movies", "TV Shows"]
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public init() {}
    
    private var filteredResults: [MediaItem] {
        if selectedFilter == "Movies" {
            return engine.searchResults.filter { $0.mediaType == .movie }
        } else if selectedFilter == "TV Shows" {
            return engine.searchResults.filter { $0.mediaType == .tvShow }
        }
        return engine.searchResults
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input Field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    
                    TextField("Search movies, TV shows, genres...", text: $query)
                        .foregroundColor(.white)
                        .tint(.white)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, newValue in
                            Task {
                                await engine.search(query: newValue)
                            }
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                            engine.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Filter Chips
                if !engine.searchResults.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filters, id: \.self) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                                        .foregroundColor(selectedFilter == filter ? .black : .white.opacity(0.8))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(selectedFilter == filter ? Color.white : Color.white.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
                
                // Content Area
                if query.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Search anything across cinema & streaming")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredResults.isEmpty {
                    VStack(spacing: 10) {
                        Text("No titles found")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Try searching for a different title, actor, or genre")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredResults) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    PosterCardView(item: item, width: 160)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
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
