import SwiftUI

public struct TVWatchlistView: View {
    @ObservedObject private var store = WatchlistStore.shared
    @State private var selectedItem: MediaItem?
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 36)
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ANODE")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Your Watchlist")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                
                if store.records.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Your Watchlist is empty")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Browse movies and shows on Discover or Streaming and add them to your queue.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(store.records) { record in
                                Button {
                                    selectedItem = record.mediaItem
                                } label: {
                                    TVMediaCardView(item: record.mediaItem, width: 220)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 60)
                    }
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
}
