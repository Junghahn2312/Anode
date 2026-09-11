import SwiftUI

public struct TVSettingsView: View {
    @ObservedObject private var watchlist = WatchlistStore.shared
    @ObservedObject private var trakt = TraktStore.shared
    @State private var showingClearAlert: Bool = false
    @State private var preferredQuality: String = "4K Ultra HD"
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.04, green: 0.04, blue: 0.05)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 42) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Text("SYSTEM PREFERENCES")
                                .font(.system(size: 13, weight: .black))
                                .tracking(2.2)
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.cyan.opacity(0.18))
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                                        )
                                    )
                            
                            Text("ANODE")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Text("Settings")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Catalog status, playback options, and local library preferences.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 140)
                
                // Settings Grid / Panels
                VStack(spacing: 28) {
                    // Catalog & Data Integration Panel
                    settingsCard(title: "CATALOG & INTEGRATION") {
                        VStack(spacing: 14) {
                            settingsRow(title: "Data Provider", value: "TMDB & JustWatch", systemImage: "network")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Catalog Scope", value: "Worldwide Global", systemImage: "globe")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "API Status", value: "Connected", isStatusGreen: true, systemImage: "checkmark.circle.fill")
                        }
                    }
                    
                    // Trakt & Continue Watching Panel
                    settingsCard(title: "TRAKT & CONTINUE WATCHING") {
                        VStack(spacing: 16) {
                            HStack {
                                Label("Trakt Status", systemImage: "play.tv.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                if trakt.isConnected {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text(trakt.username.isEmpty ? "Connected" : "@\(trakt.username)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text("Offline / Standalone")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            if let code = trakt.deviceCode {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("ACTIVATE ON PHONE OR COMPUTER")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(.cyan)
                                    
                                    Text("1. Visit https://trakt.tv/activate")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 12) {
                                        Text("2. Enter Code:")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(code.userCode)
                                            .font(.system(size: 24, weight: .black, design: .monospaced))
                                            .foregroundColor(.cyan)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.cyan.opacity(0.18))
                                            )
                                    }
                                    
                                    Button("Cancel Code Request") {
                                        trakt.cancelDeviceAuth()
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            } else if !trakt.isConnected {
                                HStack {
                                    Text("Sync playback progress and watch history seamlessly.")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Button {
                                        Task { await trakt.startDeviceAuth() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "link")
                                            Text("Connect with Trakt")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(Color.red.opacity(0.75))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                HStack {
                                    Button {
                                        Task { await trakt.refresh() }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text(trakt.isSyncing ? "Syncing..." : "Sync Now")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.18))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Button(role: .destructive) {
                                        trakt.disconnect()
                                    } label: {
                                        Text("Disconnect Trakt")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(Color.red.opacity(0.18))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Sample Data Toggle
                            Toggle(isOn: Binding(
                                get: { trakt.useSampleData },
                                set: { trakt.toggleSampleData($0) }
                            )) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Sample Continue Watching")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Display curated continue watching items on Home when offline or unlinked.")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    
                    // Library & Watchlist Panel
                    settingsCard(title: "MY LIST & LIBRARY") {
                        VStack(spacing: 16) {
                            HStack {
                                Label("Saved Titles", systemImage: "bookmark.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(watchlist.items.count) items in My List")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            if !watchlist.items.isEmpty {
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    Spacer()
                                    Button(role: .destructive) {
                                        showingClearAlert = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14, weight: .bold))
                                            Text("Clear My List")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(Color.red.opacity(0.25)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Experience & Playback Panel
                    settingsCard(title: "PLAYBACK & EXPERIENCE") {
                        VStack(spacing: 14) {
                            settingsRow(title: "Hero Presentation", value: "Stationary Showcase", systemImage: "tv")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Trailer Resolution", value: preferredQuality, systemImage: "play.rectangle.fill")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Remote Physics", value: "Fluid 10-Foot Focus", systemImage: "cursorarrow.rays")
                        }
                    }
                    
                    // Privacy & Architecture Panel
                    settingsCard(title: "PRIVACY & SECURITY") {
                        VStack(spacing: 14) {
                            settingsRow(title: "Accounts", value: "Zero Accounts Needed", systemImage: "person.crop.circle.badge.checkmark")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Telemetry & Tracking", value: "Disabled / Zero Tracking", systemImage: "shield.fill")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Storage Mode", value: "Local Secure Sandbox", systemImage: "lock.fill")
                        }
                    }
                    
                    // About Panel
                    settingsCard(title: "ABOUT ANODE") {
                        VStack(spacing: 14) {
                            settingsRow(title: "Version", value: "1.0.0 (Build 2026.1)", systemImage: "info.circle")
                            Divider().background(Color.white.opacity(0.1))
                            settingsRow(title: "Platform", value: "Apple TV (tvOS)", systemImage: "appletv")
                        }
                    }
                }
                .padding(.horizontal, 60)
            }
                .padding(.bottom, 100)
            }
            .ignoresSafeArea()
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
    
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .tracking(1.4)
                .foregroundColor(.white.opacity(0.45))
            
            VStack(alignment: .leading) {
                content()
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: 1000)
    }
    
    private func settingsRow(title: String, value: String, isStatusGreen: Bool = false, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if isStatusGreen {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                }
            } else {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
