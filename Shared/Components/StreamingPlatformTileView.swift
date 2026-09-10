import SwiftUI

public struct StreamingPlatformTileView: View {
    let provider: StreamingProvider
    let backdropURL: URL?
    let width: CGFloat
    let onFocus: ((StreamingProvider) -> Void)?
    
    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif
    
    public init(
        provider: StreamingProvider,
        backdropURL: URL? = nil,
        width: CGFloat = 260,
        onFocus: ((StreamingProvider) -> Void)? = nil
    ) {
        self.provider = provider
        self.backdropURL = backdropURL ?? StreamingPlatformTileView.defaultBackdrop(for: provider)
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 0.5625 // 16:9 ratio
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Base background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
            
            // Right-aligned movie still with gradient blend
            if let backdropURL {
                HStack {
                    Spacer()
                    CachedAsyncImage(url: backdropURL)
                        .frame(width: width * 0.65, height: height)
                        .clipped()
                        .mask(
                            LinearGradient(
                                colors: [Color.clear, Color.black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            // Left-aligned brand styling
            VStack(alignment: .leading, spacing: 4) {
                brandLogoView
                
                Text("Catalog")
                    .font(.system(size: width * 0.05, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.leading, width * 0.08)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                #if os(tvOS)
                .stroke(
                    isFocused ? Color(red: 0.0, green: 0.72, blue: 1.0) : Color.white.opacity(0.12),
                    lineWidth: isFocused ? 3.5 : 0.8
                )
                #else
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                #endif
        )
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .shadow(
            color: isFocused ? Color(red: 0.0, green: 0.72, blue: 1.0).opacity(0.4) : Color.black.opacity(0.6),
            radius: isFocused ? 18 : 8,
            x: 0,
            y: isFocused ? 8 : 4
        )
        .animation(.easeInOut(duration: 0.22), value: isFocused)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(provider)
            }
        }
        #else
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        #endif
    }
    
    @ViewBuilder
    private var brandLogoView: some View {
        switch provider.id {
        case StreamingProvider.netflix.id:
            Text("NETFLIX")
                .font(.system(size: width * 0.09, weight: .black))
                .tracking(1.0)
                .foregroundColor(Color(red: 0.9, green: 0.05, blue: 0.08))
        case StreamingProvider.appleTV.id:
            HStack(spacing: 2) {
                Image(systemName: "apple.logo")
                    .font(.system(size: width * 0.08, weight: .bold))
                Text("tv+")
                    .font(.system(size: width * 0.09, weight: .bold))
            }
            .foregroundColor(.white)
        case StreamingProvider.disneyPlus.id:
            Text("Disney+")
                .font(.system(size: width * 0.09, weight: .black))
                .foregroundColor(Color(red: 0.15, green: 0.5, blue: 1.0))
        case StreamingProvider.primeVideo.id:
            VStack(alignment: .leading, spacing: 0) {
                Text("prime video")
                    .font(.system(size: width * 0.075, weight: .heavy))
                    .foregroundColor(Color(red: 0.0, green: 0.65, blue: 0.9))
            }
        case StreamingProvider.max.id:
            Text("MAX")
                .font(.system(size: width * 0.11, weight: .black))
                .tracking(2.0)
                .foregroundColor(Color(red: 0.0, green: 0.35, blue: 1.0))
        default:
            Text(provider.name.uppercased())
                .font(.system(size: width * 0.08, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    public static func defaultBackdrop(for provider: StreamingProvider) -> URL? {
        switch provider.id {
        case StreamingProvider.netflix.id:
            // Ripley / Stranger Things style
            return URL(string: "https://image.tmdb.org/t/p/w780/zU0htwkhNvBQdVSIKB9s6hgVeFK.jpg")
        case StreamingProvider.appleTV.id:
            // Severance backdrop
            return URL(string: "https://image.tmdb.org/t/p/w780/ixgFmf1X59PUZam2qbAfskx2gQr.jpg")
        case StreamingProvider.disneyPlus.id:
            // Shogun backdrop
            return URL(string: "https://image.tmdb.org/t/p/w780/bwSmgmd90hCWwqOKQYTEraeOZhJ.jpg")
        case StreamingProvider.primeVideo.id:
            // Oppenheimer backdrop
            return URL(string: "https://image.tmdb.org/t/p/w780/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg")
        case StreamingProvider.max.id:
            // Dune 2 backdrop
            return URL(string: "https://image.tmdb.org/t/p/w780/xOMo8BRK7PfcJv9JCnx7s520Wio.jpg")
        default:
            return nil
        }
    }
}
