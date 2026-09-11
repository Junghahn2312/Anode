import SwiftUI

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case accounts = "Accounts"
    case audioVideo = "Audio and Video"
    case library = "Library & Storage"
    case providers = "Data Providers"
    case privacy = "Privacy & Security"
    case about = "System & About"
    case sleep = "Sleep Now"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    
    public var hasChevron: Bool {
        self != .sleep
    }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .accounts: return "play.tv.fill"
        case .audioVideo: return "tv.fill"
        case .library: return "bookmark.fill"
        case .providers: return "network"
        case .privacy: return "hand.raised.fill"
        case .about: return "info.circle.fill"
        case .sleep: return "powersleep"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .general: return Color(red: 0.55, green: 0.55, blue: 0.60)
        case .accounts: return Color(red: 0.90, green: 0.10, blue: 0.20)
        case .audioVideo: return Color(red: 0.65, green: 0.30, blue: 0.90)
        case .library: return Color(red: 1.00, green: 0.60, blue: 0.00)
        case .providers: return Color(red: 0.05, green: 0.50, blue: 0.95)
        case .privacy: return Color(red: 0.35, green: 0.35, blue: 0.85)
        case .about: return Color(red: 0.40, green: 0.40, blue: 0.45)
        case .sleep: return Color(red: 0.80, green: 0.25, blue: 0.25)
        }
    }
    
    public var summary: String {
        switch self {
        case .general:
            return "Application behavior, startup tab, and interface options."
        case .accounts:
            return "Trakt watch history sync, scrobbling, and user profiles."
        case .audioVideo:
            return "Playback resolution, HDR video streaming, and spotlight behaviors."
        case .library:
            return "Saved titles, offline metadata cache, and local storage."
        case .providers:
            return "The Movie Database (TMDB) API and JustWatch streaming engines."
        case .privacy:
            return "Zero-telemetry policy, local sandbox encryption, and security."
        case .about:
            return "Anode tvOS version, legal attributions, and licenses."
        case .sleep:
            return "Put Anode into power-saving standby mode."
        }
    }
}

public struct TVSettingsView: View {
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var trakt = TraktStore.shared
    
    @State private var activeSubpage: SettingsSection? = nil
    @State private var showingClearAlert: Bool = false
    @State private var showingSleepAlert: Bool = false
    @State private var isSleeping: Bool = false
    @State private var preferredQuality: String = "4K Ultra HD"
    @State private var heroMode: String = "Stationary Showcase"
    @State private var initialTab: Int = UserDefaults.standard.integer(forKey: "InitialTab")
    @State private var cacheRefreshStatus: String? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Darker than Apple TV grey: Sleek charcoal slate background
            Color(red: 0.10, green: 0.10, blue: 0.12)
                .ignoresSafeArea()
            
            // Subtle ambient depth gradient
            LinearGradient(
                colors: [
                    Color.white.opacity(0.02),
                    Color.clear,
                    Color.black.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isSleeping {
                // Standby black screen (wakes on any tap)
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            AnodeLogoView(size: 160)
                                .opacity(0.20)
                            Text("Press any button to resume")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.40)) {
                            isSleeping = false
                        }
                    }
            } else if let section = activeSubpage {
                subpageView(for: section)
                    .transition(.opacity)
            } else {
                rootSettingsView
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .onExitCommand {
            if activeSubpage != nil {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                    activeSubpage = nil
                }
            }
        }
        .onChange(of: activeSubpage) { _, newSubpage in
            AppNavigation.shared.isTopBarVisible = (newSubpage == nil)
        }
        .onAppear {
            AppNavigation.shared.isTopBarVisible = (activeSubpage == nil)
        }
        .onDisappear {
            AppNavigation.shared.isTopBarVisible = true
        }
        .alert("Clear My List?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                watchlist.clear()
            }
        } message: {
            Text("This will remove all saved movies and TV shows from your personal watchlist.")
        }
        .alert("Enter Standby?", isPresented: $showingSleepAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sleep", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.40)) {
                    isSleeping = true
                }
            }
        } message: {
            Text("Anode will pause background data updates and enter low-power standby mode.")
        }
    }
    
    // MARK: - Root Settings Screen (Matching Apple TV Settings Exactly)
    
    private var rootSettingsView: some View {
        VStack(spacing: 24) {
            // Centered Settings title positioned slightly higher up
            Text("Settings")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white.opacity(0.90))
                .padding(.top, 95)
            
            HStack(alignment: .center) {
                Spacer()
                
                // Left: Large Squircle Card with Anode Logo (Centre Left of Screen, slightly higher and bigger)
                ZStack {
                    RoundedRectangle(cornerRadius: 64, style: .continuous)
                        .fill(Color(red: 0.17, green: 0.17, blue: 0.20))
                        .frame(width: 440, height: 440)
                        .overlay(
                            RoundedRectangle(cornerRadius: 64, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 32, y: 10)
                    
                    AnodeLogoView(size: 270)
                }
                .frame(width: 480)
                
                Spacer()
                
                // Right: Clean Vertical Settings Rows (Centre Right of Screen, bigger and slightly higher up)
                VStack(spacing: 12) {
                    ForEach(SettingsSection.allCases) { section in
                        TVSettingsMenuRowButton(
                            title: section.title,
                            showChevron: section.hasChevron
                        ) {
                            handleSectionClick(section)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .frame(width: 640)
                .focusSection()
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, -20)
        }
    }
    
    private func handleSectionClick(_ section: SettingsSection) {
        if section == .sleep {
            showingSleepAlert = true
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                activeSubpage = section
            }
        }
    }
    
    // MARK: - Subpage Drill-Down View (Matching Apple TV Settings App Format)
    
    private func subpageView(for section: SettingsSection) -> some View {
        HStack(alignment: .top, spacing: 60) {
            // Left Column: Navigation Title, Back Button, Category Preview/Logo & Description
            VStack(alignment: .leading, spacing: 22) {
                // Back Button (< Settings)
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        activeSubpage = nil
                    }
                } label: {
                    TVSettingsBackButtonLabel()
                }
                .buttonStyle(.tvCard)
                
                Text(section.title)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                // Category Squircle Preview Card
                ZStack {
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .fill(Color(red: 0.17, green: 0.17, blue: 0.20))
                        .frame(width: 340, height: 340)
                        .overlay(
                            RoundedRectangle(cornerRadius: 48, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.40), radius: 24, y: 8)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(section.iconColor)
                                .frame(width: 90, height: 90)
                            Image(systemName: section.icon)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 360)
                
                Text(section.summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.60))
                    .lineSpacing(4)
                    .frame(width: 340, alignment: .leading)
            }
            .frame(width: 380)
            .padding(.leading, 80)
            .padding(.top, 55)
            .focusSection()
            
            // Right Column: Apple TV Grouped List of Setting Items
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    switch section {
                    case .general:
                        generalDetailPane
                    case .accounts:
                        traktDetailPane
                    case .audioVideo:
                        playbackDetailPane
                    case .library:
                        watchlistDetailPane
                    case .providers:
                        providersDetailPane
                    case .privacy:
                        privacyDetailPane
                    case .about:
                        aboutDetailPane
                    case .sleep:
                        EmptyView()
                    }
                }
                .padding(.top, 55)
                .padding(.trailing, 80)
                .padding(.bottom, 80)
                .frame(width: 640)
            }
            .focusSection()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - 0. General Detail Pane
    
    private var generalDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("STARTUP TAB")
                
                let tabs: [(Int, String)] = [(0, "Home"), (1, "Discovery"), (2, "Cinema"), (3, "Search")]
                ForEach(tabs, id: \.0) { tab in
                    TVSettingsRowItem(
                        title: tab.1,
                        isSelected: initialTab == tab.0
                    ) {
                        initialTab = tab.0
                        UserDefaults.standard.set(tab.0, forKey: "InitialTab")
                    }
                }
                
                sectionFooter("Choose which section opens automatically when Anode launches.")
            }
            
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("MAINTENANCE")
                
                TVSettingsRowItem(
                    title: "Clear Image Cache",
                    icon: "trash"
                ) {
                    URLCache.shared.removeAllCachedResponses()
                }
                
                sectionFooter("Removes temporary downloaded poster and backdrop images to reclaim space.")
            }
        }
    }
    
    // MARK: - 1. Trakt Detail Pane
    
    private var traktDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("TRAKT INTEGRATION")
                
                if let code = trakt.deviceCode {
                    TVSettingsRowItem(
                        title: "Activation Code",
                        value: code.userCode
                    ) {}
                    
                    TVSettingsRowItem(
                        title: "Cancel Code Request",
                        icon: "xmark.circle.fill",
                        isDestructive: true
                    ) {
                        trakt.cancelDeviceAuth()
                    }
                    
                    sectionFooter("Visit trakt.tv/activate on your phone or computer and enter the code above.")
                } else if !trakt.isConnected {
                    TVSettingsRowItem(
                        title: "Connect with Trakt",
                        icon: "link"
                    ) {
                        Task { await trakt.startDeviceAuth() }
                    }
                    
                    sectionFooter("Sign in with your Trakt account to synchronize watch history and continue watching queues.")
                } else {
                    TVSettingsRowItem(
                        title: "Status",
                        value: "Connected"
                    ) {}
                    
                    TVSettingsRowItem(
                        title: "Username",
                        value: "@\(trakt.username)"
                    ) {}
                    
                    TVSettingsRowItem(
                        title: trakt.isSyncing ? "Syncing..." : "Sync Watchlist Now",
                        icon: "arrow.triangle.2.circlepath"
                    ) {
                        Task { await trakt.refresh() }
                    }
                    
                    TVSettingsRowItem(
                        title: "Disconnect Account",
                        icon: "rectangle.portrait.and.arrow.right",
                        isDestructive: true
                    ) {
                        trakt.disconnect()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("CONTINUE WATCHING ROW")
                
                TVSettingsRowItem(
                    title: "Curated Standalone Queue",
                    value: trakt.useSampleData ? "Enabled" : "Disabled",
                    isSelected: trakt.useSampleData
                ) {
                    trakt.toggleSampleData(!trakt.useSampleData)
                }
                
                sectionFooter("Enables a curated continue watching queue on the Home tab when unlinked or offline.")
            }
        }
    }
    
    // MARK: - 2. Video & Playback Detail Pane
    
    private var playbackDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("TRAILER STREAM QUALITY")
                
                let qualities = ["4K Ultra HD", "1080p Full HD", "Auto Dynamic"]
                ForEach(qualities, id: \.self) { quality in
                    TVSettingsRowItem(
                        title: quality,
                        isSelected: preferredQuality == quality
                    ) {
                        preferredQuality = quality
                    }
                }
                
                sectionFooter("Sets the target video resolution for YouTube trailer playback.")
            }
            
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("HERO SPOTLIGHT BEHAVIOR")
                
                let modes = ["Stationary Showcase", "Ambient Crossfade"]
                ForEach(modes, id: \.self) { mode in
                    TVSettingsRowItem(
                        title: mode,
                        isSelected: heroMode == mode
                    ) {
                        heroMode = mode
                    }
                }
                
                sectionFooter("Controls whether top banner hero spotlights auto-advance periodically.")
            }
        }
    }
    
    // MARK: - 3. Watchlist & Library Detail Pane
    
    private var watchlistDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("WATCHLIST LIBRARY")
                
                TVSettingsRowItem(
                    title: "Saved Titles",
                    value: "\(watchlist.items.count) titles"
                ) {}
                
                TVSettingsRowItem(
                    title: "Saved Movies",
                    value: "\(watchlist.items.filter { $0.mediaType == .movie }.count)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Saved Series",
                    value: "\(watchlist.items.filter { $0.mediaType == .tvShow }.count)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Clear All Saved Titles",
                    icon: "trash.fill",
                    isDestructive: true
                ) {
                    showingClearAlert = true
                }
                
                sectionFooter("All saved titles are persisted securely within the local sandbox container.")
            }
        }
    }
    
    // MARK: - 4. Providers Detail Pane
    
    private var providersDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("METADATA & WATCH ENGINES")
                
                TVSettingsRowItem(
                    title: "The Movie Database (TMDB)",
                    value: "Connected"
                ) {}
                
                TVSettingsRowItem(
                    title: "JustWatch Streaming Engine",
                    value: "Active"
                ) {}
                
                TVSettingsRowItem(
                    title: "Network Connection",
                    value: "Online"
                ) {}
                
                TVSettingsRowItem(
                    title: cacheRefreshStatus ?? "Flush Metadata Cache & Reload",
                    icon: "arrow.clockwise"
                ) {
                    cacheRefreshStatus = "Flushing..."
                    Task {
                        await TMDBService.shared.clearMemoryCache()
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        await DiscoveryEngine.shared.loadAll()
                        cacheRefreshStatus = "Cache Flushed Successfully"
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        cacheRefreshStatus = nil
                    }
                }
                
                sectionFooter("Refreshes all catalog records and streaming availability data from providers.")
            }
        }
    }
    
    // MARK: - 5. Privacy Detail Pane
    
    private var privacyDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("PRIVACY & SECURITY")
                
                TVSettingsRowItem(
                    title: "Telemetry & Tracking",
                    value: "Disabled"
                ) {}
                
                TVSettingsRowItem(
                    title: "Watchlist Data",
                    value: "Local Device Only"
                ) {}
                
                TVSettingsRowItem(
                    title: "Ad Identifier (IDFA)",
                    value: "Never Requested"
                ) {}
                
                TVSettingsRowItem(
                    title: "Network Security",
                    value: "HTTPS Only"
                ) {}
                
                sectionFooter("Anode is engineered with zero analytics collection and zero user tracking.")
            }
        }
    }
    
    // MARK: - 6. About Detail Pane
    
    private var aboutDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("ABOUT ANODE")
                
                TVSettingsRowItem(
                    title: "Application Version",
                    value: "1.0.0 (Build 2026.09)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Target Platform",
                    value: "tvOS 17.0+"
                ) {}
                
                TVSettingsRowItem(
                    title: "Framework",
                    value: "SwiftUI Native"
                ) {}
                
                TVSettingsRowItem(
                    title: "Architecture",
                    value: "arm64 Apple Silicon"
                ) {}
                
                TVSettingsRowItem(
                    title: "License",
                    value: "MIT"
                ) {}
                
                sectionFooter("Unified cinema and streaming discovery built for Apple TV.")
            }
        }
    }
    
    // MARK: - Reusable UI Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .tracking(1.4)
            .foregroundColor(.white.opacity(0.40))
            .padding(.leading, 12)
            .padding(.top, 4)
    }
    
    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.45))
            .lineSpacing(2)
            .padding(.leading, 12)
            .padding(.top, 2)
    }
}

// MARK: - Anode Logo Display View

public struct AnodeLogoView: View {
    public var size: CGFloat = 220
    
    public init(size: CGFloat = 220) {
        self.size = size
    }
    
    public var body: some View {
        if let uiImage = UIImage(named: "AnodeLogo") ?? UIImage(contentsOfFile: "/Volumes/NetworkSSD/Anode/logo-alpha.png") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "film.stack.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Root Settings Menu Row Button (Matching Apple TV Design)

private struct TVSettingsMenuRowButton: View {
    let title: String
    let showChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            TVSettingsMenuRowLabel(title: title, showChevron: showChevron)
        }
        .buttonStyle(.tvCard)
    }
}

private struct TVSettingsMenuRowLabel: View {
    let title: String
    let showChevron: Bool
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 21, weight: isFocused ? .bold : .medium))
                .foregroundColor(isFocused ? .black : .white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isFocused ? Color.black.opacity(0.60) : Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.06), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .zIndex(isFocused ? 10 : 1)
        .shadow(color: isFocused ? Color.white.opacity(0.40) : Color.clear, radius: 16, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}

// MARK: - Back Button (< Settings)

private struct TVSettingsBackButtonLabel: View {
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundColor(isFocused ? .black : .white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isFocused ? Color.white : Color.white.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(isFocused ? Color.white : Color.white.opacity(0.18), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 10, y: 3)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}

// MARK: - Unified Apple TV Settings Row Item

public struct TVSettingsRowItem: View {
    let title: String
    var value: String? = nil
    var icon: String? = nil
    var isSelected: Bool = false
    var isDestructive: Bool = false
    var showChevron: Bool = false
    let action: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    public init(
        title: String,
        value: String? = nil,
        icon: String? = nil,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        showChevron: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.showChevron = showChevron
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDestructive ? (isFocused ? .red : .red.opacity(0.90)) : (isFocused ? .black : .white))
                }
                
                Text(title)
                    .font(.system(size: 20, weight: isFocused || isSelected ? .bold : .medium))
                    .foregroundColor(isDestructive ? (isFocused ? .red : .red.opacity(0.90)) : (isFocused ? .black : .white))
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(isFocused ? Color.black.opacity(0.70) : Color.white.opacity(0.50))
                }
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isFocused ? .black : .cyan)
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isFocused ? Color.black.opacity(0.60) : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 24)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? Color.white : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Color.white : Color.white.opacity(0.06), lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .shadow(color: isFocused ? (isDestructive ? Color.red.opacity(0.35) : Color.white.opacity(0.40)) : Color.clear, radius: 14, y: 4)
            .zIndex(isFocused ? 10 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
        }
        .buttonStyle(.tvCard)
    }
}
