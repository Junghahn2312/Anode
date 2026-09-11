import SwiftUI

public enum SettingsSection: String, CaseIterable, Identifiable {
    case trakt
    case providers
    case watchlist
    case playback
    case privacy
    case about
    
    public var id: String { rawValue }
}

public struct TVSettingsView: View {
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var trakt = TraktStore.shared
    
    @State private var selectedSection: SettingsSection = .trakt
    @State private var showingClearAlert: Bool = false
    @State private var preferredQuality: String = "4K Ultra HD"
    @State private var heroMode: String = "Stationary Showcase"
    @State private var cacheRefreshStatus: String? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.04),
                    Color.blue.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            HStack(alignment: .top, spacing: 56) {
                leftMasterColumn
                    .frame(width: 540)
                    .focusSection()
                
                rightDetailColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focusSection()
            }
            .padding(.leading, 80)
            .padding(.trailing, 80)
            .padding(.top, 130)
            .padding(.bottom, 60)
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
    }
    
    // MARK: - Left Master Settings Menu
    
    private var leftMasterColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("PREFERENCES")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.0)
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                    
                    Text("SYSTEM")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.50))
                }
                
                Text("Settings")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACCOUNTS & SYNC")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.40))
                            .padding(.leading, 8)
                        
                        TVSettingsRowButton(
                            section: .trakt,
                            icon: "play.tv.fill",
                            iconColor: Color(red: 0.90, green: 0.10, blue: 0.20),
                            title: "Trakt & Sync",
                            value: trakt.isConnected ? (trakt.username.isEmpty ? "Connected" : "@\(trakt.username)") : "Sign In",
                            isSelected: selectedSection == .trakt,
                            onSelect: { selectedSection = .trakt }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATALOG & LIBRARY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.40))
                            .padding(.leading, 8)
                        
                        TVSettingsRowButton(
                            section: .providers,
                            icon: "network",
                            iconColor: Color(red: 0.05, green: 0.50, blue: 0.95),
                            title: "Data Providers",
                            value: "TMDB & JustWatch",
                            isSelected: selectedSection == .providers,
                            onSelect: { selectedSection = .providers }
                        )
                        
                        TVSettingsRowButton(
                            section: .watchlist,
                            icon: "bookmark.fill",
                            iconColor: Color(red: 1.00, green: 0.60, blue: 0.00),
                            title: "My List",
                            value: "\(watchlist.items.count) saved",
                            isSelected: selectedSection == .watchlist,
                            onSelect: { selectedSection = .watchlist }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PLAYBACK & DISPLAY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.40))
                            .padding(.leading, 8)
                        
                        TVSettingsRowButton(
                            section: .playback,
                            icon: "tv.fill",
                            iconColor: Color(red: 0.65, green: 0.30, blue: 0.90),
                            title: "Video & Playback",
                            value: preferredQuality,
                            isSelected: selectedSection == .playback,
                            onSelect: { selectedSection = .playback }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SYSTEM & ABOUT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.40))
                            .padding(.leading, 8)
                        
                        TVSettingsRowButton(
                            section: .privacy,
                            icon: "hand.raised.fill",
                            iconColor: Color(red: 0.35, green: 0.35, blue: 0.85),
                            title: "Privacy & Security",
                            value: "Zero Telemetry",
                            isSelected: selectedSection == .privacy,
                            onSelect: { selectedSection = .privacy }
                        )
                        
                        TVSettingsRowButton(
                            section: .about,
                            icon: "info.circle.fill",
                            iconColor: Color(red: 0.55, green: 0.55, blue: 0.60),
                            title: "About Anode",
                            value: "1.0.0",
                            isSelected: selectedSection == .about,
                            onSelect: { selectedSection = .about }
                        )
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    // MARK: - Right Detail Inspector Pane
    
    private var rightDetailColumn: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                switch selectedSection {
                case .trakt:
                    traktDetailPane
                case .providers:
                    providersDetailPane
                case .watchlist:
                    watchlistDetailPane
                case .playback:
                    playbackDetailPane
                case .privacy:
                    privacyDetailPane
                case .about:
                    aboutDetailPane
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 60)
            .animation(.easeInOut(duration: 0.28), value: selectedSection)
        }
    }
    
    // MARK: - 1. Trakt Detail Pane
    
    private var traktDetailPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.90, green: 0.10, blue: 0.20))
                        .frame(width: 64, height: 64)
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trakt Integration")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Automatically sync watch history, continue watching progress, and ratings across your devices.")
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
                Text("CONTINUE WATCHING ROW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.40))
                    .padding(.leading, 8)
                
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
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.05, green: 0.50, blue: 0.95))
                        .frame(width: 64, height: 64)
                    Image(systemName: "network")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metadata & Watch Providers")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Live catalog integration querying TMDB API v3 and JustWatch global streaming availability.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
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
                        await DiscoveryEngine.shared.loadAll()
                        cacheRefreshStatus = "Cache Flushed Successfully"
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        cacheRefreshStatus = nil
                    }
                }
                
                Text("Re-queries live endpoints for the latest theatrical releases and streaming availability updates.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.50))
                    .padding(.leading, 8)
            }
        }
    }
    
    // MARK: - 3. Watchlist Detail Pane
    
    private var watchlistDetailPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 1.00, green: 0.60, blue: 0.00))
                        .frame(width: 64, height: 64)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Library & Watchlist")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Saved movies, television series, and bookmarks stored securely in local app storage.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
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
            
            VStack(alignment: .leading, spacing: 10) {
                let moviesCount = watchlist.items.filter { $0.mediaType == .movie }.count
                let tvCount = watchlist.items.filter { $0.mediaType == .tvShow }.count
                
                detailRow(label: "Total Titles Saved", value: "\(watchlist.items.count)", icon: "tray.full.fill")
                detailRow(label: "Movies", value: "\(moviesCount)", icon: "film.fill")
                detailRow(label: "TV Shows", value: "\(tvCount)", icon: "tv")
                detailRow(label: "Storage Location", value: "Local tvOS Sandbox", icon: "internaldrive")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            if !watchlist.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    TVSettingsActionButton(
                        title: "Clear All Saved Titles",
                        icon: "trash",
                        isDestructive: true
                    ) {
                        showingClearAlert = true
                    }
                    
                    Text("Permanently removes all bookmarked movies and TV series from your device library.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.50))
                        .padding(.leading, 8)
                }
            }
        }
    }
    
    // MARK: - 4. Playback Detail Pane
    
    private var playbackDetailPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.65, green: 0.30, blue: 0.90))
                        .frame(width: 64, height: 64)
                    Image(systemName: "tv.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video & Playback Options")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Configure streaming resolution, trailer audio formats, and hero spotlight preferences.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
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
            
            VStack(alignment: .leading, spacing: 12) {
                Text("TRAILER RESOLUTION")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.40))
                    .padding(.leading, 8)
                
                VStack(spacing: 8) {
                    TVSettingsChoiceButton(title: "4K Ultra HD (HDR)", isSelected: preferredQuality == "4K Ultra HD") {
                        preferredQuality = "4K Ultra HD"
                    }
                    TVSettingsChoiceButton(title: "1080p Full HD", isSelected: preferredQuality == "1080p Full HD") {
                        preferredQuality = "1080p Full HD"
                    }
                    TVSettingsChoiceButton(title: "Auto (Bandwidth Dynamic)", isSelected: preferredQuality == "Auto") {
                        preferredQuality = "Auto"
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("HERO SPOTLIGHT DISPLAY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.40))
                    .padding(.leading, 8)
                
                VStack(spacing: 8) {
                    TVSettingsChoiceButton(title: "Stationary Showcase (20s Rotation)", isSelected: heroMode == "Stationary Showcase") {
                        heroMode = "Stationary Showcase"
                    }
                    TVSettingsChoiceButton(title: "Continuous Ambient Crossfade", isSelected: heroMode == "Continuous Crossfade") {
                        heroMode = "Continuous Crossfade"
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Privacy Detail Pane
    
    private var privacyDetailPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.35, green: 0.35, blue: 0.85))
                        .frame(width: 64, height: 64)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy & Security Architecture")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Built with Apple TV native sandboxing principles: zero tracking, zero mandatory accounts.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
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
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Mandatory Accounts", value: "Zero (Direct Native Access)", icon: "person.crop.circle.badge.checkmark", isGreen: true)
                detailRow(label: "Telemetry & Diagnostics", value: "Disabled / Zero Tracking", icon: "shield.slash.fill", isGreen: true)
                detailRow(label: "Advertising Identifiers", value: "None Collected", icon: "eye.slash.fill", isGreen: true)
                detailRow(label: "Data Storage", value: "Encrypted On-Device Sandbox", icon: "lock.fill", isGreen: true)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            Text("Anode never transmits user viewing habits, browsing queries, or library items to third-party ad networks.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.50))
                .padding(.leading, 8)
        }
    }
    
    // MARK: - 6. About Detail Pane
    
    private var aboutDetailPane: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    Image(systemName: "appletv.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anode for Apple TV")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("High-performance media discovery experience built natively with SwiftUI for tvOS.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
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
            
            VStack(alignment: .leading, spacing: 10) {
                detailRow(label: "Version", value: "1.0.0", icon: "info.circle")
                detailRow(label: "Build", value: "2026.1 (Stable)", icon: "hammer.fill")
                detailRow(label: "Target Platform", value: "tvOS 17.0+", icon: "applelogo")
                detailRow(label: "Interface Design", value: "10-Foot Fluid Remote Physics", icon: "cursorarrow.rays")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            Text("Powered by The Movie Database and JustWatch API services. All film and television poster artwork, logos, and backdrops remain copyright of their respective producers and studios.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.45))
                .lineSpacing(3)
                .padding(.leading, 8)
        }
    }
    
    // MARK: - Helper Detail Row
    
    private func detailRow(label: String, value: String, icon: String, isGreen: Bool = false) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.80))
            
            Spacer()
            
            if isGreen {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.60))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple TV Master Row Button (Full Focus Support)

public struct TVSettingsRowButton: View {
    let section: SettingsSection
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    public var body: some View {
        Button(action: onSelect) {
            TVSettingsRowButtonLabel(
                section: section,
                icon: icon,
                iconColor: iconColor,
                title: title,
                value: value,
                isSelected: isSelected,
                onFocusAction: onSelect
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TVSettingsRowButtonLabel: View {
    let section: SettingsSection
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let isSelected: Bool
    let onFocusAction: () -> Void
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isFocused ? .black : .white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(isFocused ? .black.opacity(0.70) : .white.opacity(0.55))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isFocused ? .black.opacity(0.50) : .white.opacity(0.30))
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isFocused ? Color.white : (isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isFocused ? 0.0 : (isSelected ? 0.20 : 0.06)), lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.30) : Color.clear, radius: 10, y: 3)
        .animation(.easeInOut(duration: 0.22), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocusAction()
            }
        }
    }
}

// MARK: - Apple TV Action Button (Full Focus Support)

public struct TVSettingsActionButton: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            TVSettingsActionButtonLabel(title: title, icon: icon, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }
}

private struct TVSettingsActionButtonLabel: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundColor(isFocused ? (isDestructive ? .white : .black) : (isDestructive ? .red : .white))
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(isFocused ? (isDestructive ? Color.red : Color.white) : (isDestructive ? Color.red.opacity(0.20) : Color.white.opacity(0.12)))
        )
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.30) : Color.clear, radius: 10, y: 4)
        .animation(.easeInOut(duration: 0.20), value: isFocused)
    }
}

// MARK: - Apple TV Choice Button (Full Focus Support)

public struct TVSettingsChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            TVSettingsChoiceButtonLabel(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct TVSettingsChoiceButtonLabel: View {
    let title: String
    let isSelected: Bool
    
    @Environment(\.isFocused) private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFocused ? .black : .white)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isFocused ? .black : .cyan)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color.white : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isFocused ? 0.0 : (isSelected ? 0.20 : 0.06)), lineWidth: 1)
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.30) : Color.clear, radius: 10, y: 4)
        .animation(.easeInOut(duration: 0.20), value: isFocused)
    }
}
