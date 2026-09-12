import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = ""
    @State private var selectedItem: MediaItem?
    @State private var selectedActor: CastMember?
    @State private var focusedSearchItem: MediaItem?
    @State private var activeRowIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    public init() {}
    
    private var ambientBackdropItem: MediaItem? {
        focusedSearchItem ?? engine.searchMovieResults.first ?? engine.searchTVResults.first ?? engine.searchResults.first
    }
    
    public var body: some View {
        GeometryReader { screenGeo in
            let screenWidth = max(screenGeo.size.width, UIScreen.main.bounds.width)
            let screenHeight = max(screenGeo.size.height, UIScreen.main.bounds.height)
            
            ZStack(alignment: .topLeading) {
                // Fixed Full-Screen Background Matching User Photo
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.16, blue: 0.26),
                            Color(red: 0.02, green: 0.09, blue: 0.16),
                            Color(red: 0.01, green: 0.04, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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
                            
                            Color.black.opacity(0.55)
                        }
                        .id(item.id)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.50), value: item.id)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .ignoresSafeArea()
                
                // Main Content Column
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Search Bar Area - Only component visible at the top
                    searchBarArea
                        .padding(.horizontal, 60)
                    
                    // 2. Subtle Divider Line
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, 60)
                    
                    // 3. Search Results or Empty State
                    if query.isEmpty {
                        emptyStatePlaceholder(screenHeight: screenHeight)
                    } else {
                        resultsContentArea
                    }
                }
                .padding(.top, 110)
            }
            .frame(width: screenWidth, height: screenHeight)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
        .fullScreenCover(item: $selectedActor) { member in
            TVPersonDetailView(member: member)
        }
        .onChange(of: AppNavigation.shared.focusSearchTrigger) { _, _ in
            isSearchFocused = true
        }
    }
    
    // MARK: - Search Bar Area
    
    private var searchBarArea: some View {
        HStack(spacing: 18) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(isSearchFocused ? .white : .white.opacity(0.60))
            
            TextField("Search movies, shows, people...", text: $query)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    triggerSearch(text: query)
                }
                .onChange(of: query) { _, newQuery in
                    triggerSearch(text: newQuery)
                }
            
            if !query.isEmpty {
                Button {
                    query = ""
                    triggerSearch(text: "")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                }
                .buttonStyle(.tvCard)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSearchFocused ? Color.white.opacity(0.20) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSearchFocused ? Color.white : Color.white.opacity(0.15), lineWidth: isSearchFocused ? 2.5 : 1)
        )
        .scaleEffect(isSearchFocused ? 1.02 : 1.0)
        .shadow(color: isSearchFocused ? Color.white.opacity(0.35) : Color.clear, radius: 14)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSearchFocused)
        .onMoveCommand { direction in
            if direction == .up {
                isSearchFocused = false
                AppNavigation.shared.focusTopBarTrigger += 1
            }
        }
    }
    
    // MARK: - Empty State Placeholder
    
    private func emptyStatePlaceholder(screenHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(maxHeight: 140)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.35))
            
            Text("Search Movies, TV Shows & People")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white.opacity(0.90))
            
            Text("Type to search...")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.40))
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    // MARK: - Populated Search Results Area
    
    private var resultsContentArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 36) {
                // Section 1: People / Actors
                if !engine.searchPeopleResults.isEmpty {
                    peopleSection
                }
                
                // Section 2: Movies
                if !engine.searchMovieResults.isEmpty {
                    TVContentRowView(
                        title: "Movies",
                        items: engine.searchMovieResults,
                        showCinemaBadge: false,
                        isRowActive: activeRowIndex == 1,
                        horizontalPadding: 60,
                        onHover: { item in
                            withAnimation(.easeInOut(duration: 0.40)) {
                                focusedSearchItem = item
                                activeRowIndex = 1
                            }
                        }
                    ) { item in
                        selectedItem = item
                    }
                }
                
                // Section 3: TV Shows
                if !engine.searchTVResults.isEmpty {
                    TVContentRowView(
                        title: "TV Shows",
                        items: engine.searchTVResults,
                        showCinemaBadge: false,
                        isRowActive: activeRowIndex == 2,
                        horizontalPadding: 60,
                        onHover: { item in
                            withAnimation(.easeInOut(duration: 0.40)) {
                                focusedSearchItem = item
                                activeRowIndex = 2
                            }
                        }
                    ) { item in
                        selectedItem = item
                    }
                }
                
                // When query yields zero total results
                if engine.searchPeopleResults.isEmpty && engine.searchMovieResults.isEmpty && engine.searchTVResults.isEmpty && !engine.isLoading {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "film")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white.opacity(0.30))
                        Text("No results found for \"\(query)\"")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.70))
                        Text("Check the spelling or try searching for another actor, title, or genre")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.40))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - People / Cast Row
    
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PEOPLE")
                .font(.system(size: 17, weight: .bold))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(engine.searchPeopleResults) { person in
                        Button {
                            selectedActor = person
                        } label: {
                            TVPersonSearchCardView(person: person)
                        }
                        .buttonStyle(.tvCard)
                        .onMoveCommand { direction in
                            if direction == .up {
                                isSearchFocused = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 10)
            }
        }
        .focusSection()
    }
    
    private func triggerSearch(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await engine.search(query: trimmed)
        }
    }
}

// MARK: - Person Search Card View (Circular Picture with Name)

private struct TVPersonSearchCardView: View {
    let person: CastMember
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .frame(width: 116, height: 116)
                
                if let profileURL = person.highResProfileURL ?? person.profileURL {
                    CachedAsyncImage(url: profileURL, contentMode: .fill)
                        .frame(width: 116, height: 116)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .overlay(
                Circle()
                    .stroke(isFocused ? Color.white : Color.white.opacity(0.10), lineWidth: isFocused ? 3 : 1)
            )
            .shadow(color: isFocused ? Color.white.opacity(0.40) : Color.clear, radius: 14, y: 4)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
            
            VStack(spacing: 3) {
                Text(person.name)
                    .font(.system(size: 15, weight: isFocused ? .bold : .semibold))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.90))
                    .lineLimit(1)
                    .frame(width: 130)
                
                Text(person.character)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .frame(width: 130)
            }
        }
        .frame(width: 136)
    }
}
