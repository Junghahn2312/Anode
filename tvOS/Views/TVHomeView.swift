import SwiftUI

public struct TVHomeView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var focusedBackdropURL: URL?
    @State private var selectedItem: MediaItem?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dynamic Background Artwork driven by Focus Engine
            if let backdropURL = focusedBackdropURL ?? engine.cinemaMovies.first?.backdropURL(size: "original") {
                CachedAsyncImage(url: backdropURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.75),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .animation(.easeInOut(duration: 0.4), value: focusedBackdropURL)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Header Brand
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ANODE")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("What should I watch?")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)
                    
                    // In Theaters Now
                    tvSection(title: "In Theaters Now", items: engine.cinemaMovies)
                    
                    // Trending Everywhere
                    tvSection(title: "Trending Everywhere", items: engine.trendingItems)
                    
                    // Streaming Pulse (Netflix, Apple TV+, etc.)
                    tvSection(title: "Streaming Pulse", items: engine.streamingItems)
                    
                    // Critically Acclaimed
                    tvSection(title: "Critically Acclaimed", items: engine.topRated)
                    
                    // Upcoming Radar
                    tvSection(title: "Upcoming Radar", items: engine.upcoming)
                }
                .padding(.bottom, 80)
            }
        }
        .sheet(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    @ViewBuilder
    private func tvSection(title: String, items: [MediaItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 36) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                TVMediaCardView(item: item, width: 220) { focusedItem in
                                    self.focusedBackdropURL = focusedItem.backdropURL(size: "original")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 10)
                }
            }
        }
    }
}
