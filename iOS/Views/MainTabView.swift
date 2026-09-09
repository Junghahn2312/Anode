import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(0)
            
            StreamingPulseView()
                .tabItem {
                    Label("Streaming", systemImage: "play.tv")
                }
                .tag(1)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bookmark")
                }
                .tag(3)
        }
        .tint(.white)
    }
}
