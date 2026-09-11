import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = "Tom"
    @State private var selectedItem: MediaItem?
    @State private var focusedSearchItem: MediaItem?
    @State private var activeRowIndex: Int = 0
    
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
    
    public init() {}
    
    private var ambientBackdropItem: MediaItem? {
        focusedSearchItem ?? engine.searchResults.first ?? engine.cinemaMovies.first ?? engine.trendingItems.first
    }
    
    private func handleRowHover(_ item: MediaItem, rowIndex: Int) {
        withAnimation(.easeInOut(duration: 0.50)) {
            self.focusedSearchItem = item
        }
        if activeRowIndex != rowIndex {
            withAnimation(.easeInOut(duration: 0.50)) {
                self.activeRowIndex = rowIndex
            }
        }
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background (100% Viewport, Zero Black Spaces)
                ZStack {
                    Color(red: 0.04, green: 0.04, blue: 0.05)
                        .ignoresSafeArea()
                    
                    if let item = ambientBackdropItem {
                        ZStack {
                            CachedAsyncImage(
                                url: item.backdropURL(size: "w1280") ?? item.posterURL(size: "original"),
                                contentMode: .fill
                            )
                            .frame(width: screenWidth, height: screenHeight)
                            .clipped()
                            
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            
                            Color.black.opacity(0.42)
                        }
                        .id(item.id)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.55), value: item.id)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .ignoresSafeArea()
                
                HStack(alignment: .top, spacing: 48) {
                    // Left Rail: Search Input & Curated Trending Searches (Frosted Glass)
                    VStack(alignment: .leading, spacing: 18) {
                        // Perfectly Aligned Search Field
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white.opacity(0.70))
                            
                            TextField("Search...", text: $query)
                                .textFieldStyle(.plain)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .onChange(of: query) { _, newValue in
                                    Task {
                                        await engine.search(query: newValue)
                                    }
                                }
                        }
                        .padding(.horizontal, 18)
                        .frame(height: 54)
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
                            .padding(.top, 4)
                            .padding(.horizontal, 6)
                        
                        // Vertical Suggestions List
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
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
                            .padding(.bottom, 60)
                        }
                    }
                    .frame(width: 320)
                    .focusSection()
                    
                    // Right Content Area: Results in Horizontal Expanding Card Rows (Zero Clipping/Merging)
                    VStack(alignment: .leading, spacing: 16) {
                        let displayItems = engine.searchResults.isEmpty && query.isEmpty
                            ? engine.cinemaMovies + engine.trendingItems
                            : engine.searchResults
                        
                        if displayItems.isEmpty {
                            VStack(spacing: 14) {
                                Spacer()
                                Image(systemName: "film")
                                    .font(.system(size: 54, weight: .light))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No matching titles found")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Try searching for an actor, title, or genre")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                searchRowsSection(displayItems: displayItems)
                                    .padding(.top, 8)
                                    .padding(.bottom, 120)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 140)
                .padding(.horizontal, 60)
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .task {
            if !query.isEmpty && engine.searchResults.isEmpty {
                await engine.search(query: query)
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    @ViewBuilder
    private func searchRowsSection(displayItems: [MediaItem]) -> some View {
        let movieResults = displayItems.filter { $0.mediaType == .movie }
        let tvResults = displayItems.filter { $0.mediaType == .tvShow }
        
        VStack(alignment: .leading, spacing: 32) {
            if !movieResults.isEmpty && !tvResults.isEmpty {
                // Row 0: Movies
                TVContentRowView(
                    title: "Movies",
                    items: movieResults,
                    showCinemaBadge: false,
                    isRowActive: activeRowIndex == 0,
                    horizontalPadding: 0,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    selectedItem = item
                }
                
                // Row 1: TV Shows & Series
                TVContentRowView(
                    title: "Series & TV Shows",
                    items: tvResults,
                    showCinemaBadge: false,
                    isRowActive: activeRowIndex == 1,
                    horizontalPadding: 0,
                    onHover: { handleRowHover($0, rowIndex: 1) }
                ) { item in
                    selectedItem = item
                }
            } else if query.isEmpty {
                // Discoveries when query is empty
                TVContentRowView(
                    title: "Popular Discoveries",
                    items: displayItems,
                    showCinemaBadge: false,
                    isRowActive: activeRowIndex == 0,
                    horizontalPadding: 0,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    selectedItem = item
                }
                
                if !engine.cinemaMovies.isEmpty {
                    TVContentRowView(
                        title: "In Theatres",
                        items: engine.cinemaMovies,
                        showCinemaBadge: true,
                        isRowActive: activeRowIndex == 1,
                        horizontalPadding: 0,
                        onHover: { handleRowHover($0, rowIndex: 1) }
                    ) { item in
                        selectedItem = item
                    }
                }
            } else {
                let topMatches = Array(displayItems.prefix(12))
                let moreMatches = Array(displayItems.dropFirst(12))
                
                TVContentRowView(
                    title: "Top Results for \"\(query)\"",
                    items: topMatches,
                    showCinemaBadge: false,
                    isRowActive: activeRowIndex == 0,
                    horizontalPadding: 0,
                    onHover: { handleRowHover($0, rowIndex: 0) }
                ) { item in
                    selectedItem = item
                }
                
                if !moreMatches.isEmpty {
                    TVContentRowView(
                        title: "More Results",
                        items: moreMatches,
                        showCinemaBadge: false,
                        isRowActive: activeRowIndex == 1,
                        horizontalPadding: 0,
                        onHover: { handleRowHover($0, rowIndex: 1) }
                    ) { item in
                        selectedItem = item
                    }
                }
            }
        }
    }
}

// MARK: - Refined Apple TV Search Suggestion Button

private struct TVSearchSuggestionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            TVSearchSuggestionLabel(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct TVSearchSuggestionLabel: View {
    let title: String
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: isFocused || isSelected ? .bold : .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isFocused ? .white : .cyan)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.24) : (isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isFocused ? 0.95 : (isSelected ? 0.25 : 0.08)), lineWidth: isFocused ? 2.5 : 1)
        )
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .shadow(color: isFocused ? Color.black.opacity(0.40) : Color.clear, radius: 10, y: 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}
