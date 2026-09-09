import SwiftUI

public struct TVMediaDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(item: MediaItem) {
        self.item = item
    }
    
    public var body: some View {
        ZStack {
            // Full-screen backdrop
            CachedAsyncImage(url: item.backdropURL(size: "original"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.black.opacity(0.85), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            HStack(alignment: .top, spacing: 60) {
                // Poster
                CachedAsyncImage(url: item.posterURL(size: "w500"))
                    .frame(width: 380, height: 570)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.8), radius: 30, x: 0, y: 15)
                
                // Details
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let tagline = item.tagline, !tagline.isEmpty {
                            Text(tagline.uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text(item.title)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Metadata Row
                        HStack(spacing: 18) {
                            if !item.formattedRating.isEmpty {
                                RatingBadge(rating: item.formattedRating)
                            }
                            
                            if !item.yearString.isEmpty {
                                Text(item.yearString)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            if !item.formattedRuntime.isEmpty {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.3))
                                Text(item.formattedRuntime)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            if let cert = item.certification {
                                Text(cert)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
                            }
                        }
                        
                        // Action Buttons (Focusable)
                        HStack(spacing: 20) {
                            if let trailer = item.trailers.first, let url = trailer.youtubeURL {
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                        Text("Play Trailer")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(minWidth: 180, minHeight: 60)
                                }
                            }
                            
                            Button {
                                watchlist.toggleWatchlist(item: item)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: watchlist.contains(id: item.id) ? "checkmark" : "plus")
                                    Text(watchlist.contains(id: item.id) ? "In Watchlist" : "Add to Watchlist")
                                        .fontWeight(.semibold)
                                }
                                .frame(minWidth: 200, minHeight: 60)
                            }
                        }
                        .padding(.top, 10)
                        
                        // Streaming Availability
                        if !item.streamingProviders.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("STREAMING ON")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                HStack(spacing: 12) {
                                    ForEach(item.streamingProviders) { provider in
                                        Text(provider.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        // Synopsis
                        if !item.overview.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SYNOPSIS")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text(item.overview)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(6)
                            }
                        }
                    }
                    .padding(.top, 40)
                    .padding(.trailing, 60)
                }
            }
            .padding(60)
        }
    }
}
