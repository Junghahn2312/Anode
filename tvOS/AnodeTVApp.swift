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
                
                TVDiscoveryView()
                    .tabItem {
                        Label("Discovery", systemImage: "sparkles")
                    }
                    .tag(1)
                
                TVCinemaView()
                    .tabItem {
                        Label("Cinema", systemImage: "ticket")
                    }
                    .tag(2)
                
                TVSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)
                
                TVSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(4)
            }
            .preferredColorScheme(.dark)
        }
    }
}
