import SwiftUI

public struct TVCinemaView: View {
    @ObservedObject private var engine = DiscoveryEngine.shared
    @State private var selectedItem: MediaItem?
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 36) {
                // Header Banner
                cinemaHeader
                    .padding(.horizontal, 60)
                    .padding(.top, 48)
                
                // Now in Cinemas Row
                if !engine.cinemaNow.isEmpty {
                    cinemaRow(
                        title: "Now in Cinemas",
                        subtitle: "Experience on the big screen this week",
                        items: engine.cinemaNow,
                        isLandscape: false
                    )
                }
                
                // Coming Soon to Cinemas Row (Landscape 16:9)
                if !engine.cinemaUpcoming.isEmpty {
                    cinemaRow(
                        title: "Coming Soon to Cinemas",
                        subtitle: "Upcoming theatrical releases hitting the big screen worldwide",
                        items: engine.cinemaUpcoming,
                        isLandscape: true
                    )
                }
                
                // Popular Theatrical Releases
                if !engine.cinemaMovies.isEmpty {
                    cinemaRow(
                        title: "Critically Acclaimed in Theatres",
                        subtitle: "Highest audience and critical reception",
                        items: engine.cinemaMovies.filter { $0.rating >= 7.5 },
                        isLandscape: false
                    )
                }
            }
            .padding(.bottom, 80)
        }
        .fullScreenCover(item: $selectedItem) { item in
            TVMediaDetailView(item: item)
        }
    }
    
    private var cinemaHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("CINEMA DISCOVERY")
                    .font(.system(size: 13, weight: .black))
                    .tracking(2.0)
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.2)))
                
                Text("GLOBAL THEATRES")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text("In Theatres Now")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
            
            Text("Discover theatrical releases currently showing in cinemas worldwide.")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .frame(maxWidth: 800, alignment: .leading)
        }
    }
    
    private func cinemaRow(title: String, subtitle: String?, items: [MediaItem], isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 60)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            if isLandscape {
                                TVLandscapeCardView(
                                    item: item,
                                    width: 380,
                                    subtitle: item.releaseDate ?? "Coming Soon"
                                )
                            } else {
                                TVMediaCardView(
                                    item: item,
                                    width: 210,
                                    showCinemaBadge: true
                                )
                            }
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
