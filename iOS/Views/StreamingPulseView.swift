import SwiftUI

public struct StreamingPulseView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var selectedItem: MediaItem?
    
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STREAMING PULSE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Trending on Services")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Streaming Platform Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StreamingProvider.allMajor) { provider in
                                StreamingProviderPill(
                                    provider: provider,
                                    isSelected: engine.selectedProvider.id == provider.id
                                ) {
                                    engine.selectedProvider = provider
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Grid of Media for the selected provider
                    if engine.streamingItems.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Loading catalog...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(engine.streamingItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    PosterCardView(item: item, width: 160)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.black.ignoresSafeArea())
            .sheet(item: $selectedItem) { item in
                MediaDetailView(item: item)
            }
        }
    }
}
