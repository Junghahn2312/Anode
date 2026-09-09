import SwiftUI

public struct MediaDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchlist = WatchlistStore.shared
    @State private var showingTrailer = false
    
    public init(item: MediaItem) {
        self.item = item
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Backdrop
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: item.backdropURL(size: "w1280"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.3), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        if let tagline = item.tagline, !tagline.isEmpty {
                            Text(tagline.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(item.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 8)
                    }
                    .padding(20)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Meta row: Rating, Year, Runtime, Certification
                    HStack(spacing: 12) {
                        if !item.formattedRating.isEmpty {
                            RatingBadge(rating: item.formattedRating)
                        }
                        
                        if !item.yearString.isEmpty {
                            Text(item.yearString)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if !item.formattedRuntime.isEmpty {
                            Text("•")
                                .foregroundColor(.white.opacity(0.3))
                            Text(item.formattedRuntime)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let cert = item.certification {
                            Text(cert)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Action Buttons (Trailer & Watchlist)
                    HStack(spacing: 12) {
                        // Trailer Button
                        if let trailer = item.trailers.first, let url = trailer.youtubeURL {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Trailer")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        
                        // Watchlist Toggle
                        Button {
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            #endif
                            watchlist.toggleWatchlist(item: item)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: watchlist.contains(id: item.id) ? "checkmark" : "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text(watchlist.contains(id: item.id) ? "In Watchlist" : "Watchlist")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(watchlist.contains(id: item.id) ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Streaming Availability
                    if !item.streamingProviders.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("STREAMING ON")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.5))
                            
                            HStack(spacing: 8) {
                                ForEach(item.streamingProviders) { provider in
                                    Text(provider.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Synopsis
                    if !item.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SYNOPSIS")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(item.overview)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Cast Carousel
                    if !item.cast.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TOP CAST")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(item.cast) { member in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 54, height: 54)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .foregroundColor(.white.opacity(0.4))
                                                )
                                            
                                            Text(member.name)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            Text(member.character)
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}
