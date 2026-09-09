import SwiftUI

public struct TVSearchView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var query: String = ""
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
                        
                        Text("Search")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Search movies, TV shows, genres...", text: $query)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .onChange(of: query) { _, newValue in
                            Task {
                                await engine.search(query: newValue)
                            }
                        }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 60)
                
                if query.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Search anything across cinema & streaming")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if engine.searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Text("No titles found")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Try searching for a different title, actor, or genre")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(engine.searchResults) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    TVMediaCardView(item: item, width: 220)
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
