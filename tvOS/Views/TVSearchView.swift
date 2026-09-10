import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = "Tom"
    @State private var selectedItem: MediaItem?
    
    private let suggestions: [String] = [
        "Tom Cruise",
        "Tom Hanks",
        "Christopher Nolan",
        "Dune",
        "Batman",
        "Cillian Murphy",
        "Gary Oldman",
        "Stranger Things",
        "Oppenheimer",
        "The Godfather",
        "Action",
        "Sci-Fi",
        "Comedy",
        "Thriller"
    ]
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 28),
        GridItem(.flexible(), spacing: 28),
        GridItem(.flexible(), spacing: 28),
        GridItem(.flexible(), spacing: 28)
    ]
    
    public init() {}
    
    private var ambientBackdropItem: MediaItem? {
        engine.searchResults.first ?? engine.cinemaMovies.first ?? engine.trendingItems.first
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            ZStack {
                // Base Pure Black
                Color.black.ignoresSafeArea()
                
                // Ambient Atmospheric Glow
                if let item = ambientBackdropItem {
                    CachedAsyncImage(url: item.backdropURL(size: "w780"), contentMode: .fill)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        .blur(radius: 110)
                        .opacity(0.22)
                        .clipped()
                        .ignoresSafeArea()
                }
                
                HStack(alignment: .top, spacing: 44) {
                    // Left Column: Search Bar & Curated Suggestion Rail (Frosted Glass)
                    VStack(alignment: .leading, spacing: 20) {
                        // Search Input with Frosted Glass
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("Search...", text: $query)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                                .onChange(of: query) { _, newValue in
                                    Task {
                                        await engine.search(query: newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                        
                        Text("TRENDING SEARCHES")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                        
                        // Suggestions List
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    TVSearchSuggestionButton(
                                        title: suggestion,
                                        isSelected: query.lowercased() == suggestion.lowercased()
                                    ) {
                                        self.query = suggestion
                                        Task {
                                            await engine.search(query: suggestion)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 320)
                    
                    // Right Column: 4-Column Poster Grid
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            if !query.isEmpty {
                                Text("Results for \"\(query)\"")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("Popular Discoveries")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        
                        let displayItems = engine.searchResults.isEmpty && query.isEmpty
                            ? engine.cinemaMovies + engine.trendingItems
                            : engine.searchResults
                        
                        if displayItems.isEmpty {
                            VStack(spacing: 14) {
                                Spacer()
                                Image(systemName: "film")
                                    .font(.system(size: 50, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No matching titles found")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Try searching for an actor, title, or genre")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVGrid(columns: gridColumns, spacing: 32) {
                                    ForEach(displayItems) { item in
                                        Button {
                                            selectedItem = item
                                        } label: {
                                            TVMediaCardView(item: item, width: 220)
                                        }
                                        .buttonStyle(.tvCard)
                                    }
                                }
                                .padding(.top, 6)
                                .padding(.bottom, 60)
                                .padding(.trailing, 20)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 48)
                .padding(.horizontal, 60)
            }
            .ignoresSafeArea()
        }
        .task {
            if !query.isEmpty && engine.searchResults.isEmpty {
                await engine.search(query: query)
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
}

private struct TVSearchSuggestionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: isFocused || isSelected ? .bold : .medium))
                .foregroundColor(isFocused ? .black : (isSelected ? .white : .white.opacity(0.75)))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.25) : Color.clear))
                        .background(
                            Group {
                                if !isFocused && !isSelected {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.ultraThinMaterial)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isFocused ? Color.clear : Color.white.opacity(isSelected ? 0.35 : 0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
