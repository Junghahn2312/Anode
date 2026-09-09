# Anode

A polished movie and TV discovery application built natively for iOS and Apple TV (tvOS).

Anode is inspired by the simplicity of Fusion, but focused entirely on entertainment discovery. It requires no addons, no plugins, no external accounts, and no complex setup. Its sole purpose is to give you one beautiful place to answer:

> "What should I watch?"

---

## Features

- Cinema Screenings: Current box-office releases and theatrical screenings with trailers, runtimes, and ratings.
- Trending Everywhere: High-heat movies and television series across pop culture.
- Streaming Pulse: Instant filtering across Netflix, Apple TV+, Disney+, Prime Video, and Max in one consolidated feed.
- New Releases: Fresh theatrical debuts, digital drops, and weekly series releases.
- Critically Acclaimed: Universally acclaimed cinema and audience favorites curated without algorithmic clutter.
- Upcoming Radar: Future theatrical release calendar and streaming drop dates.
- Personal Watchlist: Private on-device watchlist with watched/unwatched tracking, zero account required.

---

## Platform Experience

### iOS (iPhone & iPad)
- Quick discovery, browsing, searching, and building a watchlist on the go.
- Fast search-as-you-type with genre and media type filters.
- Native sheet presentations with high-resolution backdrops, cast carousels, and direct trailer access.
- Haptic feedback and one-handed navigation.

### Apple TV (tvOS)
- Cinematic 10-foot viewing experience designed for large screens.
- Dynamic ambient background artwork that smoothly cross-fades as the Siri Remote focus moves across titles.
- Parallax card elevation and glow effects driven by Apple TV's Focus Engine.
- Top navigation bar for seamless switching between Discover, Watchlist, and Search.

---

## Architecture & Tech Stack

- Framework: 100% SwiftUI with declarative multiplatform architecture.
- Concurrency: Modern Swift Concurrency (`async`/`await`, Actors, and Task groups).
- Persistence: Local-first JSON file storage in Application Support / Documents directory (zero telemetry, zero account requirement).
- Design System: Pitch black `#000000` aesthetic, `.ultraThinMaterial` glassmorphism, SF Symbols, and typography hierarchies. Zero emojis.

---

## Project Structure

```
Anode/
├── Anode.xcodeproj/              # Unified Xcode project (iOS & tvOS targets)
├── Shared/                       # Multiplatform shared business logic & UI
│   ├── Models/                   # MediaItem, MediaType, StreamingProvider, VideoTrailer, CastMember
│   ├── Services/                 # TMDBService, DiscoveryEngine, WatchlistStore
│   └── Components/               # PosterCardView, BackdropCardView, RatingBadge, CachedAsyncImage
├── iOS/                          # iOS application entry & views
│   ├── AnodeApp.swift            # iOS App lifecycle
│   ├── Views/                    # DiscoverView, StreamingPulseView, SearchView, WatchlistView
│   └── Assets.xcassets/          # iOS AppIcon & Colors
└── tvOS/                         # Apple TV application entry & views
    ├── AnodeTVApp.swift          # tvOS App lifecycle
    ├── Views/                    # TVHomeView, TVMediaCardView, TVMediaDetailView, TVWatchlistView
    └── Assets.xcassets/          # tvOS AppIcon & Colors
```

---

## Building & Running

### Prerequisites
- Xcode 15.0 or later (Tested on Xcode 26)
- macOS Sonoma or later

### Command Line Build

To build the iOS application for Simulator:
```bash
xcodebuild -scheme Anode-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

To build the Apple TV application for Simulator:
```bash
xcodebuild -scheme Anode-tvOS -destination 'generic/platform=tvOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

---

## License

Copyright 2026 Anode Technologies. All rights reserved.
