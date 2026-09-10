import SwiftUI

public struct TVStreamingHubView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var selectedProvider: StreamingProvider = .netflix
    @State private var providerItems: [MediaItem] = []
    @State private var selectedItem: MediaItem?
    @State private var isLoading: Bool = false
    
    private let tmdb = TMDBService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("STREAMING HUB")
                            .font(.system(size: 13, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.18)))
                        
                        Text("UNITED KINGDOM CATALOGS")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text("Select a Service")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Browse what's currently streaming across popular UK on-demand platforms.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 60)
                .padding(.top, 48)
                
                // Provider Selector Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(StreamingProvider.allCases, id: \.id) { provider in
                            ProviderPill(
                                provider: provider,
                                isSelected: provider == selectedProvider
                            ) {
                                selectedProvider = provider
                                Task { await loadProviderContent(provider) }
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 12)
                }
                
                // Selected Provider Spotlight & Catalog
                if isLoading {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 28) {
                            ForEach(0..<6, id: \.self) { _ in
                                TVSkeletonCardView(width: 210)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                    }
                } else {
                    let displayItems = providerItems.isEmpty ? engine.streamingItems : providerItems
                    
                    // Trending on selected service
                    streamingSection(
                        title: "Trending on \(selectedProvider.name)",
                        items: displayItems
                    )
                    
                    // Top Rated on selected service
                    let topRated = displayItems.filter { $0.rating >= 7.8 }
                    if !topRated.isEmpty {
                        streamingSection(
                            title: "Highest Rated on \(selectedProvider.name)",
                            items: topRated
                        )
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .task {
            await loadProviderContent(selectedProvider)
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    private func loadProviderContent(_ provider: StreamingProvider) async {
        isLoading = true
        providerItems = await tmdb.fetchStreaming(provider: provider)
        isLoading = false
    }
    
    private func streamingSection(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            TVMediaCardView(item: item, width: 210)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
            }
        }
    }
}

private struct ProviderPill: View {
    let provider: StreamingProvider
    let isSelected: Bool
    let action: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(provider.brandColor)
                    .frame(width: 10, height: 10)
                
                Text(provider.name)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected || isFocused ? .white : .white.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? provider.brandColor.opacity(0.35) : Color(white: 0.14))
            )
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .shadow(
                color: isFocused ? Color.black.opacity(0.7) : Color.clear,
                radius: 12,
                y: 4
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}
