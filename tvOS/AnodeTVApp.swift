import SwiftUI

@MainActor
public final class AppNavigation: ObservableObject {
    public static let shared = AppNavigation()
    @Published public var selectedTab: Int
    @Published public var isTopBarVisible: Bool = true
    @Published public var focusTopBarTrigger: Int = 0
    
    public init() {
        let initial = UserDefaults.standard.integer(forKey: "InitialTab")
        self.selectedTab = initial
    }
}

public struct TopTabItem: Identifiable {
    public let id: Int
    public let title: String
    public let systemImage: String
}

public let allTopTabs: [TopTabItem] = [
    TopTabItem(id: 0, title: "Home", systemImage: "house"),
    TopTabItem(id: 1, title: "Discovery", systemImage: "sparkles"),
    TopTabItem(id: 2, title: "Cinema", systemImage: "ticket"),
    TopTabItem(id: 3, title: "Search", systemImage: "magnifyingglass"),
    TopTabItem(id: 4, title: "Settings", systemImage: "gearshape")
]

public struct TVTopTabBarView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var nav = AppNavigation.shared
    @FocusState private var focusedTab: Int?
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(allTopTabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedTab = tab.id
                    }
                } label: {
                    TVTopTabButtonLabel(
                        title: tab.title,
                        systemImage: tab.systemImage,
                        isSelected: selectedTab == tab.id,
                        onFocus: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                selectedTab = tab.id
                            }
                        }
                    )
                }
                .buttonStyle(.tvCard)
                .focused($focusedTab, equals: tab.id)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
        .focusSection()
        .onChange(of: nav.focusTopBarTrigger) { _, _ in
            focusedTab = selectedTab
        }
    }
}

private struct TVTopTabButtonLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onFocus: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.75)
    }
    
    private var backgroundColor: Color {
        if isFocused { return .white }
        return isSelected ? Color.white.opacity(0.24) : Color.clear
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 15, weight: isSelected || isFocused ? .bold : .medium))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .overlay(
            Capsule().stroke(isFocused ? Color.white : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            }
        }
    }
}

@main
struct AnodeTVApp: App {
    @StateObject private var nav = AppNavigation.shared
    
    init() {
        let memoryCapacity = 200 * 1024 * 1024 // 200 MB
        let diskCapacity = 1000 * 1024 * 1024 // 1 GB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "AnodeImageCache")
        URLCache.shared = cache
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                // Active Tab Content with Smooth Soft Cross-Fade
                ZStack {
                    switch nav.selectedTab {
                    case 0:
                        TVHomeView()
                            .transition(.opacity)
                    case 1:
                        TVDiscoveryView()
                            .transition(.opacity)
                    case 2:
                        TVCinemaView()
                            .transition(.opacity)
                    case 3:
                        TVSearchView()
                            .transition(.opacity)
                    case 4:
                        TVSettingsView()
                            .transition(.opacity)
                    default:
                        TVHomeView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.45), value: nav.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                
                // Floating Top Tab Bar with smooth fade on scroll
                TVTopTabBarView(selectedTab: $nav.selectedTab)
                    .opacity(nav.isTopBarVisible ? 1.0 : 0.0)
                    .disabled(!nav.isTopBarVisible)
                    .animation(.easeInOut(duration: 0.35), value: nav.isTopBarVisible)
                    .ignoresSafeArea()
            }
            .preferredColorScheme(.dark)
        }
    }
}
