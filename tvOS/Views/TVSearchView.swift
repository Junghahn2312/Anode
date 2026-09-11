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
    
    // 5 balanced columns to fill the full width (1920px) without right-side black bars
    private let gridColumns = [
        GridItem(.flexible(), spacing: 28),
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
            ZStack(alignment: .topLeading) {
                // Continuous Cinematic Dark Canvas (Zero Black Bar Cuts)
                Color(red: 0.04, green: 0.04, blue: 0.05)
                    .ignoresSafeArea()
                
                // Ambient Atmospheric Glow Spanning Full 1920x1080 Viewport
                if let item = ambientBackdropItem {
                    CachedAsyncImage(url: item.backdropURL(size: "w780"), contentMode: .fill)
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                        .blur(radius: 110)
                        .opacity(0.32)
                        .clipped()
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.5), value: item.id)
                }
                
                HStack(alignment: .top, spacing: 36) {
                    // Left Rail: Search Input & Curated Trending Searches (Frosted Glass)
                    VStack(alignment: .leading, spacing: 18) {
                        // Search Field
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            
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
                    
                    // Right Content Area: 5-Column Full-Width Poster Grid (Zero Black Bars)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            if !query.isEmpty {
                                Text("Results for \"\(query)\"")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("Popular Discoveries")
                                    .font(.system(size: 24, weight: .bold))
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
                                .padding(.top, 4)
                                .padding(.bottom, 100)
                                .padding(.trailing, 10)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 140)
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
                .font(.system(size: 16, weight: isFocused || isSelected ? .bold : .medium))
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
