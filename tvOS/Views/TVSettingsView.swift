import SwiftUI

public enum SettingsSection: String, CaseIterable, Identifiable {
    case icloud = "iCloud"
    case accounts = "Accounts"
    case metadata = "Metadata"
    case widgets = "Widgets"
    case addons = "Addons"
    case library = "Library"
    case progress = "Progress"
    case videoPlayer = "Video Player"
    case subtitles = "Subtitles"
    case homeStyle = "Home Style"
    case iconPacks = "Icon Packs"
    case about = "About"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .icloud: return "icloud.fill"
        case .accounts: return "person.crop.circle.fill"
        case .metadata: return "square.stack.3d.up.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .addons: return "puzzlepiece.fill"
        case .library: return "folder.fill"
        case .progress: return "chart.bar.fill"
        case .videoPlayer: return "play.rectangle.fill"
        case .subtitles: return "captions.bubble.fill"
        case .homeStyle: return "paintpalette.fill"
        case .iconPacks: return "app.badge.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    public var summary: String {
        switch self {
        case .icloud:
            return "Synchronize your watchlist, playback progress, and settings via iCloud."
        case .accounts:
            return "Connect your Trakt account to sync watch history, ratings, and lists."
        case .metadata:
            return "Data providers, content language, and localized catalog caches."
        case .widgets:
            return "Configure Apple TV Top Shelf previews and home screen widgets."
        case .addons:
            return "Installed stream extensions, trailer engines, and metadata sources."
        case .library:
            return "Manage your personal watchlist, saved media, and storage."
        case .progress:
            return "Scrobbling thresholds, resume points, and episode progress tracking."
        case .videoPlayer:
            return "Streaming resolution, HDR playback preferences, and audio boost."
        case .subtitles:
            return "Default subtitle languages, font sizing, and appearance."
        case .homeStyle:
            return "Select your startup destination tab and hero presentation layout."
        case .iconPacks:
            return "Choose your preferred home screen and interface theme icon."
        case .about:
            return "Anode tvOS version, legal attributions, and licenses."
        }
    }
}

public struct TVSettingsView: View {
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var trakt = TraktStore.shared
    
    @State private var hoveredSection: SettingsSection = .addons
    @State private var activeSubpage: SettingsSection? = nil
    @State private var showingClearAlert: Bool = false
    @State private var preferredQuality: String = "1080p Full HD"
    @State private var initialTab: Int = UserDefaults.standard.integer(forKey: "InitialTab")
    @State private var cacheRefreshStatus: String? = nil
    @State private var iCloudSyncEnabled: Bool = true
    @State private var subtitleLang: String = "English"
    @State private var selectedIconTheme: String = "Default Dark"
    @FocusState private var focusedSection: SettingsSection?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dark sleek charcoal background matching screenshot
            Color(red: 0.11, green: 0.11, blue: 0.13)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.white.opacity(0.015),
                    Color.clear,
                    Color.black.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if let section = activeSubpage {
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
        .alert("Clear Personal Watchlist?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                watchlist.clear()
            }
        } message: {
            Text("This will remove all saved movies and TV shows from your personal list.")
        }
    }
    
    // MARK: - Root Settings Screen (Matching User Reference Image Exactly)
    
    private var rootSettingsView: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Half: Large Squircle Card with Hovered Section Icon and Label
            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 68, style: .continuous)
                        .fill(Color(white: 0.18))
                        .frame(width: 360, height: 360)
                        .overlay(
                            RoundedRectangle(cornerRadius: 68, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 28, y: 8)
                    
                    if hoveredSection == .addons {
                        AddonsTwinChevronLogoView(size: 160)
                    } else {
                        Image(systemName: hoveredSection.iconName)
                            .font(.system(size: 130, weight: .light))
                            .foregroundColor(.white)
                    }
                }
                .id(hoveredSection.rawValue)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: hoveredSection)
                
                Text(hoveredSection.rawValue)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // Right Half: Vertical List of Settings Options
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 9) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                                activeSubpage = section
                            }
                        } label: {
                            TVSettingsCategoryRowLabel(title: section.title) {
                                withAnimation(.easeInOut(duration: 0.20)) {
                                    self.hoveredSection = section
                                }
                            }
                        }
                        .buttonStyle(.tvCard)
                        .focused($focusedSection, equals: section)
                        .applyMoveUp(onMoveUp: section == .icloud ? {
                            focusedSection = nil
                            AppNavigation.shared.focusTopBarTrigger += 1
                        } : nil)
                    }
                }
                .padding(.top, 100)
                .padding(.bottom, 80)
                .frame(width: 540)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 60)
            .focusSection()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: AppNavigation.shared.focusSettingsTrigger) { _, _ in
            focusedSection = hoveredSection
        }
    }
    
    // MARK: - Subpage Drill-Down View
    
    private func subpageView(for section: SettingsSection) -> some View {
        HStack(alignment: .top, spacing: 60) {
            // Left Column: Navigation Title, Back Button, Category Preview Card & Description
            VStack(alignment: .leading, spacing: 22) {
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
                
                ZStack {
                    RoundedRectangle(cornerRadius: 52, style: .continuous)
                        .fill(Color(white: 0.18))
                        .frame(width: 320, height: 320)
                        .overlay(
                            RoundedRectangle(cornerRadius: 52, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 8)
                    
                    if section == .addons {
                        AddonsTwinChevronLogoView(size: 130)
                    } else {
                        Image(systemName: section.iconName)
                            .font(.system(size: 110, weight: .light))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 320)
                
                Text(section.summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.60))
                    .lineSpacing(4)
                    .frame(width: 320, alignment: .leading)
            }
            .frame(width: 360)
            .padding(.leading, 80)
            .padding(.top, 55)
            .focusSection()
            
            // Right Column: Settings Details
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    switch section {
                    case .icloud:
                        icloudDetailPane
                    case .accounts:
                        accountsDetailPane
                    case .metadata:
                        metadataDetailPane
                    case .widgets:
                        widgetsDetailPane
                    case .addons:
                        addonsDetailPane
                    case .library:
                        libraryDetailPane
                    case .progress:
                        progressDetailPane
                    case .videoPlayer:
                        videoPlayerDetailPane
                    case .subtitles:
                        subtitlesDetailPane
                    case .homeStyle:
                        homeStyleDetailPane
                    case .iconPacks:
                        iconPacksDetailPane
                    case .about:
                        aboutDetailPane
                    }
                }
                .padding(.top, 55)
                .padding(.trailing, 80)
                .padding(.bottom, 80)
                .frame(width: 620)
            }
            .focusSection()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Detail Panes
    
    private var icloudDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("ICLOUD SYNCHRONIZATION")
                
                TVSettingsRowItem(
                    title: "iCloud Sync",
                    value: iCloudSyncEnabled ? "Enabled" : "Disabled"
                ) {
                    iCloudSyncEnabled.toggle()
                }
                
                TVSettingsRowItem(
                    title: "Status",
                    value: "Connected"
                ) {}
                
                TVSettingsRowItem(
                    title: "Last Sync",
                    value: "Just Now"
                ) {}
                
                sectionFooter("Automatically syncs your watchlist and bookmarks across all Apple devices.")
            }
        }
    }
    
    private var accountsDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("TRAKT ACCOUNT INTEGRATION")
                
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
                    
                    sectionFooter("Connected as @\(trakt.username). Watch history updates automatically.")
                }
            }
        }
    }
    
    private var metadataDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("CATALOG & PROVIDERS")
                
                TVSettingsRowItem(
                    title: "Metadata Provider",
                    value: "The Movie Database (TMDB)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Language",
                    value: "English (US)"
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
    
    private var widgetsDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("APPLE TV HOME WIDGETS")
                
                TVSettingsRowItem(
                    title: "Top Shelf Display",
                    value: "Continue Watching"
                ) {}
                
                TVSettingsRowItem(
                    title: "Show Trending in Shelf",
                    value: "Enabled"
                ) {}
                
                sectionFooter("Configures the interactive showcase shown on the Apple TV home screen.")
            }
        }
    }
    
    private var addonsDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("INSTALLED ADDONS & EXTENSIONS")
                
                TVSettingsRowItem(
                    title: "Trailer Stream Engine",
                    value: "Active"
                ) {}
                
                TVSettingsRowItem(
                    title: "Rotten Tomatoes 1080p Engine",
                    value: "Enabled"
                ) {}
                
                TVSettingsRowItem(
                    title: "iTunes Previews Addon",
                    value: "Active"
                ) {}
                
                TVSettingsRowItem(
                    title: "Cinemeta Catalog Integration",
                    value: "Connected"
                ) {}
                
                sectionFooter("High-speed direct video resolution addons for live backdrop playback.")
            }
        }
    }
    
    private var libraryDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("WATCHLIST & STORAGE")
                
                TVSettingsRowItem(
                    title: "Saved Titles Count",
                    value: "\(watchlist.items.count) items"
                ) {}
                
                TVSettingsRowItem(
                    title: "Clear Watchlist",
                    icon: "trash",
                    isDestructive: true
                ) {
                    showingClearAlert = true
                }
                
                TVSettingsRowItem(
                    title: "Clear Image Cache",
                    icon: "externaldrive"
                ) {
                    URLCache.shared.removeAllCachedResponses()
                }
                
                sectionFooter("Manage your saved titles and cached media assets.")
            }
        }
    }
    
    private var progressDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("PLAYBACK PROGRESS")
                
                TVSettingsRowItem(
                    title: "Mark as Watched Threshold",
                    value: "80%"
                ) {}
                
                TVSettingsRowItem(
                    title: "Auto-Resume Playback",
                    value: "Always"
                ) {}
                
                sectionFooter("Threshold for automatic scrobbling to Trakt.")
            }
        }
    }
    
    private var videoPlayerDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("VIDEO RESOLUTION & AUDIO")
                
                let qualities = ["1080p Full HD", "4K Ultra HD", "720p HD"]
                ForEach(qualities, id: \.self) { q in
                    TVSettingsRowItem(
                        title: q,
                        isSelected: preferredQuality == q
                    ) {
                        preferredQuality = q
                    }
                }
                
                TVSettingsRowItem(
                    title: "Trailer Autoplay Delay",
                    value: "1 Second"
                ) {}
                
                sectionFooter("Trailers stream at the highest available resolution up to 1080p Full HD.")
            }
        }
    }
    
    private var subtitlesDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("SUBTITLE PREFERENCES")
                
                let langs = ["English", "Spanish", "French", "German"]
                ForEach(langs, id: \.self) { l in
                    TVSettingsRowItem(
                        title: l,
                        isSelected: subtitleLang == l
                    ) {
                        subtitleLang = l
                    }
                }
                
                sectionFooter("Preferred audio and subtitle track selection.")
            }
        }
    }
    
    private var homeStyleDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("STARTUP DESTINATION")
                
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
        }
    }
    
    private var iconPacksDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("APP ICON PACKS")
                
                let icons = ["Default Dark", "Cinema Slate", "Onyx Black"]
                ForEach(icons, id: \.self) { icon in
                    TVSettingsRowItem(
                        title: icon,
                        isSelected: selectedIconTheme == icon
                    ) {
                        selectedIconTheme = icon
                    }
                }
                
                sectionFooter("Customize the app icon presentation on tvOS.")
            }
        }
    }
    
    private var aboutDetailPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("ABOUT ANODE")
                
                TVSettingsRowItem(
                    title: "Version",
                    value: "2.0.0 (Build 2026.09)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Target Platform",
                    value: "Apple TV (tvOS 17.0+)"
                ) {}
                
                TVSettingsRowItem(
                    title: "Engine",
                    value: "SwiftUI Native"
                ) {}
                
                TVSettingsRowItem(
                    title: "License",
                    value: "MIT"
                ) {}
                
                sectionFooter("Unified cinema and streaming discovery built for Apple TV.")
            }
        }
    }
    
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

// MARK: - Addons Twin Chevron Logo View (Matching Screenshot Exact Shape)

public struct AddonsTwinChevronLogoView: View {
    public var size: CGFloat = 160
    
    public init(size: CGFloat = 160) {
        self.size = size
    }
    
    public var body: some View {
        HStack(spacing: size * 0.16) {
            singleChevron
            singleChevron
        }
        .frame(width: size, height: size)
    }
    
    private var singleChevron: some View {
        ZStack {
            // Upper angled pill
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.22, height: size * 0.52)
                .rotationEffect(.degrees(-45))
                .offset(x: size * 0.08, y: -size * 0.13)
            
            // Lower angled pill
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.22, height: size * 0.52)
                .rotationEffect(.degrees(45))
                .offset(x: size * 0.08, y: size * 0.13)
        }
    }
}

// MARK: - Category Row Label with White Hover Pill

private struct TVSettingsCategoryRowLabel: View {
    let title: String
    let onFocus: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 19, weight: isFocused ? .bold : .medium))
                .foregroundColor(isFocused ? .black : .white.opacity(0.88))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isFocused ? .black : .white.opacity(0.35))
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? Color.white : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.30) : Color.clear, radius: 10, y: 3)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            }
        }
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

// MARK: - Setting Row Item

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
                    .font(.system(size: 19, weight: isFocused || isSelected ? .bold : .medium))
                    .foregroundColor(isDestructive ? (isFocused ? .red : .red.opacity(0.90)) : (isFocused ? .black : .white))
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.system(size: 17, weight: .regular))
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
            .padding(.horizontal, 22)
            .frame(height: 56)
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
