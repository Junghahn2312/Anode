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
                            AnodeLogoView(size: 140)
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
            // Centered Settings title (Apple TV Typography)
            Text("Settings")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.white.opacity(0.90))
                .padding(.top, 95)
            
            HStack(alignment: .center, spacing: 72) {
                // Left: Large Squircle Card with Anode Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 56, style: .continuous)
                        .fill(Color(red: 0.17, green: 0.17, blue: 0.20))
                        .frame(width: 380, height: 380)
                        .overlay(
                            RoundedRectangle(cornerRadius: 56, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 28, y: 10)
                    
                    AnodeLogoView(size: 220)
                }
                .frame(width: 440)
                
                // Right: Clean Vertical Settings Rows
                ScrollView(.vertical, showsIndicators: false) {
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(width: 500)
                }
                .frame(width: 520, height: 560)
                .focusSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func handleSectionClick(_ section: SettingsSection) {
        if section == .sleep {
            showingSleepAlert = true
        } else {
            withAnimation(.easeInOut(duration: 0.32)) {
                activeSubpage = section
            }
        }
    }
    
    // MARK: - Subpage Drill-Down View
    
    private func subpageView(for section: SettingsSection) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Back Button (< Settings)
            Button {
                withAnimation(.easeInOut(duration: 0.32)) {
                    activeSubpage = nil
                }
            } label: {
                TVSettingsBackButtonLabel()
            }
            .buttonStyle(.tvCard)
            .padding(.top, 40)
            .padding(.leading, 80)
            
            HStack(alignment: .top, spacing: 60) {
                // Left Column: Category Summary Card
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 44, style: .continuous)
                            .fill(Color(red: 0.17, green: 0.17, blue: 0.20))
                            .frame(width: 280, height: 280)
                            .overlay(
                                RoundedRectangle(cornerRadius: 44, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.40), radius: 20, y: 6)
                        
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(section.iconColor)
                                    .frame(width: 80, height: 80)
                                Image(systemName: section.icon)
                                    .font(.system(size: 38, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(section.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(section.summary)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.60))
                        .multilineTextAlignment(.center)
                        .frame(width: 280)
                }
                .frame(width: 320)
                .padding(.leading, 80)
                
                // Right Column: Active Category Detail Pane
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
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
                    .padding(.trailing, 80)
                    .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - 0. General Detail Pane
    
    private var generalDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "General Preferences",
                subtitle: "Customize application startup behavior, background refreshes, and display preferences.",
                icon: "gearshape.fill",
                iconColor: SettingsSection.general.iconColor
            )
            
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("STARTUP TAB")
                
                let tabs: [(Int, String)] = [(0, "Home"), (1, "Discovery"), (2, "Cinema"), (3, "Search")]
                ForEach(tabs, id: \.0) { tab in
                    TVSettingsChoiceButton(
                        title: tab.1,
                        isSelected: initialTab == tab.0
                    ) {
                        initialTab = tab.0
                        UserDefaults.standard.set(tab.0, forKey: "InitialTab")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("MAINTENANCE")
                
                TVSettingsActionButton(
                    title: "Clear Image Cache",
                    icon: "trash",
                    isDestructive: false
                ) {
                    URLCache.shared.removeAllCachedResponses()
                }
            }
        }
    }
    
    // MARK: - 1. Trakt Detail Pane
    
    private var traktDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "Trakt Integration",
                subtitle: "Automatically sync watch history, continue watching progress, and ratings across your devices.",
                icon: "play.tv.fill",
                iconColor: SettingsSection.accounts.iconColor
            )
            
            if let code = trakt.deviceCode {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                        Text("ACTIVATION CODE ACTIVE")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.cyan)
                    }
                    
                    Text("1. Visit trakt.tv/activate on your phone or computer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        Text("2. Enter Code:")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.80))
                        
                        Text(code.userCode)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                            .tracking(4.0)
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.cyan.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.cyan.opacity(0.40), lineWidth: 1)
                                    )
                            )
                    }
                    
                    TVSettingsActionButton(
                        title: "Cancel Code Request",
                        icon: "xmark.circle.fill",
                        isDestructive: true
                    ) {
                        trakt.cancelDeviceAuth()
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            } else if !trakt.isConnected {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("NOT CONNECTED")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Sign in with your Trakt account to populate your personalized Continue Watching queue on the Home page.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                        .lineSpacing(3)
                    
                    TVSettingsActionButton(
                        title: "Connect with Trakt",
                        icon: "link",
                        isDestructive: false
                    ) {
                        Task { await trakt.startDeviceAuth() }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("CONNECTED")
                                .font(.system(size: 12, weight: .black))
                                .tracking(1.4)
                                .foregroundColor(.green)
                        }
                        
                        Text("@\(trakt.username)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 16) {
                        TVSettingsActionButton(
                            title: trakt.isSyncing ? "Syncing..." : "Sync Now",
                            icon: "arrow.triangle.2.circlepath",
                            isDestructive: false
                        ) {
                            Task { await trakt.refresh() }
                        }
                        
                        TVSettingsActionButton(
                            title: "Disconnect Account",
                            icon: "rectangle.portrait.and.arrow.right",
                            isDestructive: true
                        ) {
                            trakt.disconnect()
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
            
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("CONTINUE WATCHING ROW")
                
                TVSettingsChoiceButton(
                    title: "Curated Standalone Queue (When Unlinked)",
                    isSelected: trakt.useSampleData
                ) {
                    trakt.toggleSampleData(!trakt.useSampleData)
                }
                
                Text("Enables a curated continue watching tray on the Home tab when no Trakt account is linked or when offline.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.50))
                    .padding(.leading, 12)
            }
        }
    }
    
    // MARK: - 2. Providers Detail Pane
    
    private var providersDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "Metadata & Watch Providers",
                subtitle: "Live catalog integration querying TMDB API v3 and JustWatch global streaming availability.",
                icon: "network",
                iconColor: SettingsSection.providers.iconColor
            )
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Primary API", value: "The Movie Database (TMDB)", icon: "film")
                detailRow(label: "Availability Engine", value: "JustWatch Integration", icon: "play.circle")
                detailRow(label: "Region Filter", value: "Worldwide & Country Specific", icon: "globe")
                detailRow(label: "Network Connection", value: "Online / High Speed", icon: "wifi", isGreen: true)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            VStack(alignment: .leading, spacing: 12) {
                TVSettingsActionButton(
                    title: cacheRefreshStatus ?? "Flush Metadata Cache & Reload",
                    icon: "arrow.clockwise",
                    isDestructive: false
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
            }
        }
    }
    
    // MARK: - 3. Watchlist Detail Pane
    
    private var watchlistDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "Personal Library & Watchlist",
                subtitle: "Manage titles saved locally to your device and view catalog statistics.",
                icon: "bookmark.fill",
                iconColor: SettingsSection.library.iconColor
            )
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Total Saved Titles", value: "\(watchlist.items.count) items", icon: "square.stack.fill")
                detailRow(label: "Saved Movies", value: "\(watchlist.items.filter { $0.mediaType == .movie }.count) movies", icon: "film.fill")
                detailRow(label: "Saved Series", value: "\(watchlist.items.filter { $0.mediaType == .tvShow }.count) shows", icon: "tv.fill")
                detailRow(label: "Storage Location", value: "App Sandbox Documents", icon: "internaldrive")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            TVSettingsActionButton(
                title: "Clear All Saved Titles",
                icon: "trash.fill",
                isDestructive: true
            ) {
                showingClearAlert = true
            }
        }
    }
    
    // MARK: - 4. Playback Detail Pane
    
    private var playbackDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "Video & Playback",
                subtitle: "Configure trailer resolution preferences and hero spotlight showcase modes.",
                icon: "tv.fill",
                iconColor: SettingsSection.audioVideo.iconColor
            )
            
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("TRAILER STREAM QUALITY")
                
                let qualities = ["4K Ultra HD", "1080p Full HD", "Auto Dynamic"]
                ForEach(qualities, id: \.self) { quality in
                    TVSettingsChoiceButton(
                        title: quality,
                        isSelected: preferredQuality == quality
                    ) {
                        preferredQuality = quality
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("HERO SPOTLIGHT BEHAVIOR")
                
                let modes = [
                    ("Stationary Showcase", "Showcases 20s then softly cycles to next title."),
                    ("Ambient Crossfade", "Smoothly transitions backdrops every 8s.")
                ]
                
                ForEach(modes, id: \.0) { mode in
                    TVSettingsChoiceButton(
                        title: mode.0,
                        isSelected: heroMode == mode.0
                    ) {
                        heroMode = mode.0
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Privacy Detail Pane
    
    private var privacyDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "Privacy & Security",
                subtitle: "Anode is designed from the ground up with zero telemetry and complete privacy preservation.",
                icon: "hand.raised.fill",
                iconColor: SettingsSection.privacy.iconColor
            )
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Telemetry & Tracking", value: "Disabled (Zero Analytics)", icon: "shield.slash", isGreen: true)
                detailRow(label: "Watchlist Data", value: "Local Device Only (Encrypted)", icon: "lock.shield", isGreen: true)
                detailRow(label: "Ad Identifier (IDFA)", value: "Never Requested", icon: "xmark.shield", isGreen: true)
                detailRow(label: "Network Connections", value: "HTTPS Only (TMDB, Trakt, JustWatch)", icon: "network.badge.shield.half.filled", isGreen: true)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
    
    // MARK: - 6. About Detail Pane
    
    private var aboutDetailPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBanner(
                title: "About Anode",
                subtitle: "Anode for tvOS - Unified cinema and streaming discovery built with native SwiftUI.",
                icon: "info.circle.fill",
                iconColor: SettingsSection.about.iconColor
            )
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Application Version", value: "1.0.0 (Build 2026.09)", icon: "app.badge")
                detailRow(label: "Target Platform", value: "tvOS 17.0+ (Apple TV 4K)", icon: "appletv")
                detailRow(label: "Framework", value: "SwiftUI Native", icon: "swift")
                detailRow(label: "Architecture", value: "arm64 (Apple Silicon A15 Bionic+)", icon: "cpu")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ATTRIBUTION NOTICE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.40))
                    .padding(.leading, 8)
                
                Text("This product uses the TMDB API and JustWatch discovery services but is not endorsed or certified by TMDB or JustWatch. All film artwork and logos remain the copyright of their respective studios.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.50))
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }
        }
    }
    
    // MARK: - Reusable UI Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundColor(.white.opacity(0.40))
            .padding(.leading, 8)
    }
    
    private func headerBanner(title: String, subtitle: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
    
    private func detailRow(label: String, value: String, icon: String, isGreen: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isGreen ? .green : .white.opacity(0.60))
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.70))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isGreen ? .green : .white)
        }
        .padding(.vertical, 4)
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

// MARK: - Root Settings Menu Row Button (Matching Apple TV Screenshot)

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
                .font(.system(size: 19, weight: isFocused ? .bold : .medium))
                .foregroundColor(isFocused ? .black : .white)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isFocused ? Color.black.opacity(0.60) : Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.white : Color.white.opacity(0.06), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 14, y: 4)
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

// MARK: - Apple TV Action Button (Illuminated White Hover Matching App)

public struct TVSettingsActionButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            TVSettingsActionButtonLabel(title: title, icon: icon, isDestructive: isDestructive)
        }
        .buttonStyle(.tvCard)
    }
}

private struct TVSettingsActionButtonLabel: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    private var buttonFillColor: Color {
        if isDestructive {
            return isFocused ? Color.red : Color.red.opacity(0.20)
        } else {
            return isFocused ? Color.white : Color.white.opacity(0.12)
        }
    }
    
    private var buttonTextColor: Color {
        if isDestructive {
            return .white
        } else {
            return isFocused ? .black : .white
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundColor(buttonTextColor)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(buttonFillColor)
        )
        .overlay(
            Capsule()
                .stroke(isFocused ? Color.white : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: isFocused ? (isDestructive ? Color.red.opacity(0.4) : Color.white.opacity(0.35)) : Color.clear, radius: 12, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}

// MARK: - Apple TV Choice Button (Illuminated White Hover Matching App)

public struct TVSettingsChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            TVSettingsChoiceButtonLabel(title: title, isSelected: isSelected)
        }
        .buttonStyle(.tvCard)
    }
}

private struct TVSettingsChoiceButtonLabel: View {
    let title: String
    let isSelected: Bool
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: isFocused || isSelected ? .bold : .medium))
                .foregroundColor(isFocused ? .black : .white)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isFocused ? .black : .cyan)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.06)), lineWidth: isFocused ? 2 : 1)
        )
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 10, y: 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isFocused)
    }
}
