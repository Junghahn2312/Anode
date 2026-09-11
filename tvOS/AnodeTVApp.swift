import SwiftUI

@main
struct AnodeTVApp: App {
    @State private var selectedTab: Int = 0
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                TVHomeView()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(0)
                
                TVDiscoveryView()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Discovery", systemImage: "sparkles")
                    }
                    .tag(1)
                
                TVCinemaView()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Cinema", systemImage: "ticket")
                    }
                    .tag(2)
                
                TVSearchView()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)
                
                TVSettingsView()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(4)
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
        }
    }
}
