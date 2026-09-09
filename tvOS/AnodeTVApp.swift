import SwiftUI

@main
struct AnodeTVApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                TVHomeView()
                    .tabItem {
                        Label("Discover", systemImage: "sparkles")
                    }
                
                TVWatchlistView()
                    .tabItem {
                        Label("Watchlist", systemImage: "bookmark")
                    }
                
                TVSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
