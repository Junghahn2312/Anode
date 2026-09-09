import SwiftUI

public struct DiscoverView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var selectedItem: MediaItem?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANODE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("What should I watch?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Spotlight Hero Carousel (Backdrop Cards)
                    if !engine.cinemaMovies.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(engine.cinemaMovies) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        BackdropCardView(item: item, width: 300)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Section: In Theaters Now
                    discoverySection(title: "In Theaters Now", items: engine.cinemaMovies)
                    
                    // Section: Trending Everywhere
                    discoverySection(title: "Trending Everywhere", items: engine.trendingItems)
                    
                    // Section: New Releases
                    discoverySection(title: "New Releases", items: engine.newReleases)
                    
                    // Section: Critically Acclaimed
                    discoverySection(title: "Critically Acclaimed", items: engine.topRated)
                    
                    // Section: Upcoming Radar
                    discoverySection(title: "Upcoming Radar", items: engine.upcoming)
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(item: $selectedItem) { item in
                MediaDetailView(item: item)
            }
            .refreshable {
                await engine.loadAll()
            }
        }
    }
    
    @ViewBuilder
    private func discoverySection(title: String, items: [MediaItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                PosterCardView(item: item, width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
