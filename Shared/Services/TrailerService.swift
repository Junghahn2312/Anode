import Foundation

public final class TrailerService: @unchecked Sendable {
    public static let shared = TrailerService()
    
    private let tmdbApiKey = "156d1d139b8cf0ae10b2bce1cb46d9af"
    private var cache: [String: URL] = [:]
    private let cacheLock = NSLock()
    
    private init() {}
    
    public func resolveTrailerStream(for item: MediaItem) async -> URL? {
        let normTitle = normalizeTitle(item.title)
        let itemYear = item.yearString.isEmpty ? "" : item.yearString
        
        // Explicit check: Christopher Nolan's "The Odyssey" (2026) has no official direct stream yet.
        // Prevent matching Grant Humphreys' independent B-movie "The Odyssey (2026)".
        if normTitle == "the odyssey" && (itemYear == "2026" || item.id == 1368337) {
            return nil
        }
        
        let cacheKey = "\(item.mediaType.rawValue)_\(item.id)"
        
        cacheLock.lock()
        if let cached = cache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        // Execute Apple TV HLS and iTunes Preview resolution concurrently
        async let appleTask = resolveAppleTVStream(item: item)
        async let itunesTask = resolveITunesPreviewStream(item: item)
        
        // Priority 1: Apple TV HLS direct master stream (HD / 4K with audio)
        if let hlsURL = await appleTask {
            cacheLock.lock()
            cache[cacheKey] = hlsURL
            cacheLock.unlock()
            return hlsURL
        }
        
        // Priority 2: iTunes Store direct preview stream (.m4v with full audio)
        if let itunesURL = await itunesTask {
            cacheLock.lock()
            cache[cacheKey] = itunesURL
            cacheLock.unlock()
            return itunesURL
        }
        
        // No verified trailer found: return nil so nothing plays
        return nil
    }
    
    private func normalizeTitle(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = lower.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(filtered))
        return cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func resolveAppleTVStream(item: MediaItem) async -> URL? {
        let isMovie = item.mediaType != .tvShow
        let endpoint = isMovie ? "movie" : "tv"
        let wikidataProp = isMovie ? "P9586" : "P9751"
        let urlString = "https://api.themoviedb.org/3/\(endpoint)/\(item.id)/external_ids?api_key=\(tmdbApiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5
            request.setValue("AnodeAppleTV/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let wikidataId = json["wikidata_id"] as? String, !wikidataId.isEmpty else {
                return nil
            }
            
            // Query Wikidata claim for Apple TV content ID
            let wikiURLString = "https://www.wikidata.org/w/api.php?action=wbgetclaims&entity=\(wikidataId)&property=\(wikidataProp)&format=json"
            guard let wikiURL = URL(string: wikiURLString) else { return nil }
            
            var wikiReq = URLRequest(url: wikiURL)
            wikiReq.timeoutInterval = 3.5
            wikiReq.setValue("AnodeAppleTV/1.0 (dev.anode.appletv; contact@anode.dev)", forHTTPHeaderField: "User-Agent")
            
            let (wikiData, _) = try await URLSession.shared.data(for: wikiReq)
            guard let wikiJSON = try? JSONSerialization.jsonObject(with: wikiData) as? [String: Any],
                  let claims = wikiJSON["claims"] as? [String: Any],
                  let claimList = claims[wikidataProp] as? [[String: Any]],
                  let firstClaim = claimList.first,
                  let mainsnak = firstClaim["mainsnak"] as? [String: Any],
                  let datavalue = mainsnak["datavalue"] as? [String: Any],
                  let appleContentId = datavalue["value"] as? String, !appleContentId.isEmpty else {
                return nil
            }
            
            // Query Apple TV page to extract direct play-edge HLS playlist
            let pageType = isMovie ? "movie" : "show"
            let applePageURLString = "https://tv.apple.com/us/\(pageType)/\(appleContentId)"
            guard let applePageURL = URL(string: applePageURLString) else { return nil }
            
            var appleReq = URLRequest(url: applePageURL)
            appleReq.timeoutInterval = 4.0
            appleReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (appleHtmlData, _) = try await URLSession.shared.data(for: appleReq)
            guard let html = String(data: appleHtmlData, encoding: .utf8) else { return nil }
            
            // Verify Apple TV page contains title to prevent mismatched catalog claims
            let normItemTitle = normalizeTitle(item.title)
            let normHtml = normalizeTitle(html)
            if !normItemTitle.isEmpty && !normHtml.contains(normItemTitle) {
                return nil
            }
            
            // Regex to find https://play-edge.itunes.apple.com/...playlist.m3u8
            let pattern = "https://play-edge\\.itunes\\.apple\\.com/[^\"'\\s<>]+\\.m3u8[^\"'\\s<>]*"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches {
                if let r = Range(match.range, in: html) {
                    let rawURL = String(html[r]).replacingOccurrences(of: "&amp;", with: "&")
                    if let streamURL = URL(string: rawURL) {
                        return streamURL
                    }
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    private func resolveITunesPreviewStream(item: MediaItem) async -> URL? {
        guard let escaped = item.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let searchURLString = "https://itunes.apple.com/search?term=\(escaped)&limit=50"
        guard let url = URL(string: searchURLString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return nil
            }
            
            let isMovie = item.mediaType != .tvShow
            let normQuery = normalizeTitle(item.title)
            guard !normQuery.isEmpty else { return nil }
            
            let itemYear = item.yearString.isEmpty ? nil : item.yearString
            
            for result in results {
                let kind = result["kind"] as? String ?? ""
                
                if isMovie {
                    if kind == "feature-movie" {
                        let trackName = result["trackName"] as? String ?? ""
                        let normTrack = normalizeTitle(trackName)
                        guard !normTrack.isEmpty else { continue }
                        
                        let releaseDate = result["releaseDate"] as? String ?? ""
                        let trackYear = releaseDate.count >= 4 ? String(releaseDate.prefix(4)) : nil
                        
                        var yearMatches = true
                        if let iy = itemYear, let ty = trackYear, let iVal = Int(iy), let tVal = Int(ty) {
                            yearMatches = abs(iVal - tVal) <= 2
                        }
                        
                        if (normTrack == normQuery || normTrack.hasPrefix(normQuery) || normQuery.hasPrefix(normTrack)) && yearMatches {
                            if let previewStr = result["previewUrl"] as? String, let previewURL = URL(string: previewStr) {
                                return previewURL
                            }
                        }
                    }
                } else {
                    if kind == "tv-episode" {
                        let artistName = result["artistName"] as? String ?? ""
                        let collectionName = result["collectionName"] as? String ?? ""
                        let normArtist = normalizeTitle(artistName)
                        let normCollection = normalizeTitle(collectionName)
                        
                        if normArtist == normQuery || normCollection.hasPrefix(normQuery) || normArtist.contains(normQuery) {
                            if let previewStr = result["previewUrl"] as? String, let previewURL = URL(string: previewStr) {
                                return previewURL
                            }
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        
        // Strict policy: If no high-confidence trailer matches, return nil so nothing plays
        return nil
    }
}
