import SwiftUI

@main
struct AnodeTVApp: App {
    @State private var selectedTab: Int = 0
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                TVHomeView()
                    .tabItem {
                        Label("Discover", systemImage: "sparkles")
                    }
                    .tag(0)
                
                TVWatchlistView()
                    .tabItem {
                        Label("Watchlist", systemImage: "bookmark")
                    }
                    .tag(1)
                
                TVSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(2)
            }
            .preferredColorScheme(.dark)
        }
    }
}
