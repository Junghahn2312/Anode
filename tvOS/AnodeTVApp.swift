import SwiftUI

@MainActor
public final class AppNavigation: ObservableObject {
    public static let shared = AppNavigation()
    @Published public var selectedTab: Int
    
    public init() {
        let initial = UserDefaults.standard.integer(forKey: "InitialTab")
        self.selectedTab = initial
    }
}

@main
struct AnodeTVApp: App {
    @StateObject private var nav = AppNavigation.shared
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $nav.selectedTab) {
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
