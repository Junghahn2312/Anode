import SwiftUI

@main
struct AnodeTVApp: App {
    @State private var selectedTab: Int = 0
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                TVHomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
                
                TVCategoryBrowseView(mediaType: .movie)
                    .tabItem {
                        Label("Movies", systemImage: "film")
                    }
                    .tag(1)
                
                TVCategoryBrowseView(mediaType: .tvShow)
                    .tabItem {
                        Label("TV Shows", systemImage: "tv")
                    }
                    .tag(2)
                
                TVCinemaView()
                    .tabItem {
                        Label("Cinema", systemImage: "ticket")
                    }
                    .tag(3)
                
                TVStreamingHubView()
                    .tabItem {
                        Label("Streaming", systemImage: "play.rectangle.on.rectangle")
                    }
                    .tag(4)
                
                TVSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(5)
                
                TVWatchlistView()
                    .tabItem {
                        Label("My List", systemImage: "bookmark")
                    }
                    .tag(6)
            }
            .preferredColorScheme(.dark)
        }
    }
}
