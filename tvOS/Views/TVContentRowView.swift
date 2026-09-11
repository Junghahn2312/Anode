import SwiftUI

// MARK: - Dedicated Inline Row Info Panel (Matching Image 2)

public struct TVRowInfoPanel: View {
    let item: MediaItem
    
    public init(item: MediaItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Metadata Line (Genre • Year • Runtime • Rating Badge • Badges)
            HStack(spacing: 12) {
                if let genre = item.genreNames.first {
                    Text(genre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !item.yearString.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(item.yearString)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if !item.formattedRuntime.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(item.formattedRuntime)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if let cert = item.certification {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    Text(cert)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                }
                
                if !item.formattedRating.isEmpty {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    RatingBadge(rating: item.formattedRating)
                }
                
                if item.inCinemas {
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("IN CINEMAS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Synopsis / Overview text (Image 2)
            if !item.overview.isEmpty {
                Text(item.overview)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
                    .lineSpacing(3)
                    .frame(maxWidth: 900, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Standard Content Row with Expanding Cards & Inline Info Strip

public struct TVContentRowView: View {
    let title: String
    let items: [MediaItem]
    let showCinemaBadge: Bool
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        showCinemaBadge: Bool = false,
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.showCinemaBadge = showCinemaBadge
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 34) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TVMediaCardView(
                                item: item,
                                width: 210,
                                showCinemaBadge: showCinemaBadge
                            ) { focused in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    self.focusedItem = focused
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel (Image 2)
            if let active = focusedItem {
                TVRowInfoPanel(item: active)
                    .padding(.horizontal, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(active.id)
            }
        }
    }
}

// MARK: - Landscape Content Row with Expanding Cards & Inline Info Strip

public struct TVLandscapeRowView: View {
    let title: String
    let items: [MediaItem]
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 34) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TVLandscapeCardView(
                                item: item,
                                width: 380,
                                subtitle: item.releaseDate
                            ) { focused in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    self.focusedItem = focused
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel (Image 2)
            if let active = focusedItem {
                TVRowInfoPanel(item: active)
                    .padding(.horizontal, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(active.id)
            }
        }
    }
}

// MARK: - Top 10 Content Row with Expanding Cards & Inline Info Strip

public struct TVTopTenRowView: View {
    let title: String
    let items: [MediaItem]
    let onSelect: (MediaItem) -> Void
    
    @State private var focusedItem: MediaItem?
    
    public init(
        title: String,
        items: [MediaItem],
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.title = title
        self.items = items
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row Title
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            // Horizontal Card Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 38) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            onSelect(item)
                        } label: {
                            TopTenCardView(
                                rank: index + 1,
                                item: item,
                                width: 175
                            ) { focused in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    self.focusedItem = focused
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            
            // Inline Detail Panel (Image 2)
            if let active = focusedItem {
                TVRowInfoPanel(item: active)
                    .padding(.horizontal, 60)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(active.id)
            }
        }
    }
}
