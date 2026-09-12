import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = ""
    @State private var selectedItem: MediaItem?
    @State private var selectedActor: CastMember?
    @State private var focusedSearchItem: MediaItem?
    @State private var activeRowIndex: Int = 0
    @State private var isShowingSearchPrompt: Bool = false
    @State private var inputPromptText: String = ""
    @State private var isNumericKeyboard: Bool = false
    private enum SearchFocusTarget: Hashable {
        case searchBar
        case key(String)
    }
    
    @FocusState private var focusedTarget: SearchFocusTarget?
    
    private let letterKeys: [String] = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
        "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
        "u", "v", "w", "x", "y", "z"
    ]
    
    private let numberKeys: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "-", "/", ":", ";", "(", ")", "$", "&", "@", "\"",
        ".", ",", "?", "!", "'"
    ]
    
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
                
                // Main Content Column (Matching reference photo)
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Search Bar Area
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
        .alert("Search Movies, Shows & People", isPresented: $isShowingSearchPrompt) {
            TextField("Search titles, actors, directors...", text: $inputPromptText)
            Button("Search") {
                query = inputPromptText
                triggerSearch(text: inputPromptText)
            }
            if !query.isEmpty {
                Button("Clear", role: .destructive) {
                    query = ""
                    triggerSearch(text: "")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type an actor name, film title, or television series.")
        }
        .onChange(of: AppNavigation.shared.focusSearchTrigger) { _, _ in
            focusedTarget = .searchBar
        }
    }
    
    // MARK: - Search Bar & Keyboard Strip Area
    
    private var isSearchFocused: Bool {
        focusedTarget == .searchBar
    }
    
    private var searchBarArea: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Search Input Row (Prompt or active query)
            HStack(spacing: 16) {
                Button {
                    inputPromptText = query
                    isShowingSearchPrompt = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(isSearchFocused ? .white : .white.opacity(0.85))
                        
                        Text(query.isEmpty ? "Search movies, shows, people..." : query)
                            .font(.system(size: 30, weight: query.isEmpty ? .regular : .semibold))
                            .foregroundColor(isSearchFocused ? .white : (query.isEmpty ? .white.opacity(0.55) : .white))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSearchFocused ? Color.white.opacity(0.18) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSearchFocused ? Color.white.opacity(0.40) : Color.clear, lineWidth: 1.5)
                    )
                    .scaleEffect(isSearchFocused ? 1.02 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSearchFocused)
                }
                .buttonStyle(.tvCard)
                .focused($focusedTarget, equals: .searchBar)
                .onMoveCommand { direction in
                    if direction == .up {
                        AppNavigation.shared.focusTopBarTrigger += 1
                    } else if direction == .down {
                        focusedTarget = .key("a")
                    }
                }
                
                if !query.isEmpty {
                    Button {
                        query = ""
                        triggerSearch(text: "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white.opacity(0.70))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.tvCard)
                }
            }
            
            // On-screen character keyboard strip (123, SPACE, a-z, Backspace)
            let currentKeys = isNumericKeyboard ? numberKeys : letterKeys
            HStack(spacing: 8) {
                // Mode toggle: 123 / ABC
                Button {
                    isNumericKeyboard.toggle()
                } label: {
                    TVKeyboardKeyButtonLabel(label: isNumericKeyboard ? "ABC" : "123", width: 56, isSpecial: true)
                }
                .buttonStyle(.tvCard)
                .focused($focusedTarget, equals: .key("MODE"))
                .onMoveCommand { direction in
                    if direction == .up {
                        focusedTarget = .searchBar
                    } else if direction == .right {
                        focusedTarget = .key("SPACE")
                    } else if direction == .down {
                        focusedTarget = nil
                    }
                }
                
                // SPACE key
                Button {
                    query.append(" ")
                    triggerSearch(text: query)
                } label: {
                    TVKeyboardKeyButtonLabel(label: "SPACE", width: 74, isSpecial: true)
                }
                .buttonStyle(.tvCard)
                .focused($focusedTarget, equals: .key("SPACE"))
                .onMoveCommand { direction in
                    if direction == .up {
                        focusedTarget = .searchBar
                    } else if direction == .left {
                        focusedTarget = .key("MODE")
                    } else if direction == .right {
                        let firstKey = currentKeys.first ?? "a"
                        focusedTarget = .key(firstKey)
                    } else if direction == .down {
                        focusedTarget = nil
                    }
                }
                
                // Letters / Numbers
                ForEach(currentKeys, id: \.self) { key in
                    Button {
                        query.append(key)
                        triggerSearch(text: query)
                    } label: {
                        TVKeyboardKeyButtonLabel(label: key, width: 38, isSpecial: false)
                    }
                    .buttonStyle(.tvCard)
                    .focused($focusedTarget, equals: .key(key))
                    .onMoveCommand { direction in
                        if direction == .up {
                            focusedTarget = .searchBar
                        } else if direction == .left {
                            if let idx = currentKeys.firstIndex(of: key) {
                                if idx > 0 {
                                    focusedTarget = .key(currentKeys[idx - 1])
                                } else {
                                    focusedTarget = .key("SPACE")
                                }
                            }
                        } else if direction == .right {
                            if let idx = currentKeys.firstIndex(of: key) {
                                if idx < currentKeys.count - 1 {
                                    focusedTarget = .key(currentKeys[idx + 1])
                                } else {
                                    focusedTarget = .key("DELETE")
                                }
                            }
                        } else if direction == .down {
                            focusedTarget = nil
                        }
                    }
                }
                
                // Backspace key
                Button {
                    if !query.isEmpty {
                        query.removeLast()
                        triggerSearch(text: query)
                    }
                } label: {
                    TVKeyboardKeyButtonLabel(systemIcon: "delete.left.fill", width: 50, isSpecial: true)
                }
                .buttonStyle(.tvCard)
                .focused($focusedTarget, equals: .key("DELETE"))
                .onMoveCommand { direction in
                    if direction == .up {
                        focusedTarget = .searchBar
                    } else if direction == .left {
                        if let lastKey = currentKeys.last {
                            focusedTarget = .key(lastKey)
                        }
                    } else if direction == .down {
                        focusedTarget = nil
                    }
                }
            }
            .focusSection()
            .padding(.vertical, 4)
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
                                focusedTarget = .key("a")
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

// MARK: - On-Screen Keyboard Key Button Label

private struct TVKeyboardKeyButtonLabel: View {
    var label: String? = nil
    var systemIcon: String? = nil
    var width: CGFloat = 38
    var isSpecial: Bool = false
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        ZStack {
            if let icon = systemIcon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isFocused ? .black : .white)
            } else if let text = label {
                Text(text)
                    .font(.system(size: isSpecial ? 14 : 16, weight: isFocused ? .bold : (isSpecial ? .semibold : .medium)))
                    .foregroundColor(isFocused ? .black : .white)
            }
        }
        .frame(width: width, height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isFocused ? Color.white : (isSpecial ? Color.white.opacity(0.18) : Color.white.opacity(0.08)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1.12 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.40) : Color.clear, radius: 8, y: 2)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isFocused)
    }
}
