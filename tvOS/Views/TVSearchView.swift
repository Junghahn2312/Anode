import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = "Tom"
    @State private var selectedItem: MediaItem?
    @State private var focusedSearchItem: MediaItem?
    @State private var activeRowIndex: Int = 0
    @State private var isShowingSearchPrompt: Bool = false
    @State private var inputPromptText: String = ""
    
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
                        // Unified Apple TV Search Bar (Zero Inner Shading / Seamless Pill)
                        TVSearchBarButton(query: $query) {
                            inputPromptText = query
                            isShowingSearchPrompt = true
                        }
                        
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
        .alert("Search Movies & TV Shows", isPresented: $isShowingSearchPrompt) {
            TextField("Search titles, actors, genres...", text: $inputPromptText)
            Button("Search") {
                query = inputPromptText
                Task {
                    await engine.search(query: inputPromptText)
                }
            }
            if !query.isEmpty {
                Button("Clear Search", role: .destructive) {
                    query = ""
                    Task {
                        await engine.search(query: "")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a search term or actor name to find matching movies and television series.")
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
        .buttonStyle(.tvCard)
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
                .foregroundColor(isFocused ? .black : .white)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isFocused ? .black : .cyan)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08)), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 10, y: 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}

// MARK: - Dedicated Transparent Search Input Field (No Shading / Inset Vignette)

final class TVTransparentTextField: UITextField {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        clearBackgrounds()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        clearBackgrounds()
    }
    
    private func clearBackgrounds() {
        self.backgroundColor = .clear
        self.background = nil
        self.disabledBackground = nil
        self.layer.backgroundColor = UIColor.clear.cgColor
        self.borderStyle = .none
        
        for subview in self.subviews {
            let name = String(describing: type(of: subview))
            if name.contains("Background") || name.contains("VisualEffect") || name.contains("Effect") || name.contains("Shadow") {
                subview.isHidden = true
                subview.alpha = 0
            }
        }
    }
}

public struct TVSearchInputField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: (() -> Void)? = nil
    
    public init(text: Binding<String>, placeholder: String, onCommit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }
    
    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TVSearchInputField
        
        public init(_ parent: TVSearchInputField) {
            self.parent = parent
        }
        
        public func textFieldDidChangeSelection(_ textField: UITextField) {
            if self.parent.text != textField.text {
                self.parent.text = textField.text ?? ""
            }
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            return true
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> UITextField {
        let tf = TVTransparentTextField()
        tf.placeholder = placeholder
        tf.text = text
        tf.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        tf.textColor = .white
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.layer.backgroundColor = UIColor.clear.cgColor
        tf.background = nil
        tf.disabledBackground = nil
        tf.delegate = context.coordinator
        tf.returnKeyType = .search
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.tintColor = .white
        
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.40)]
        )
        return tf
    }
    
    public func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}


// MARK: - Unified Apple TV Search Bar Button & Label

private struct TVSearchBarButton: View {
    @Binding var query: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            TVSearchBarLabel(query: query)
        }
        .buttonStyle(.tvCard)
    }
}

private struct TVSearchBarLabel: View {
    let query: String
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(isFocused ? .black : .white.opacity(0.75))
            
            Text(query.isEmpty ? "Search movies, shows..." : query)
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(isFocused ? .black : (query.isEmpty ? .white.opacity(0.45) : .white))
                .lineLimit(1)
            
            Spacer()
            
            if !query.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isFocused ? Color.black.opacity(0.60) : Color.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.15), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 12, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}
