import Foundation

public final class TrailerService: @unchecked Sendable {
    public static let shared = TrailerService()
    
    private let tmdbApiKey = "156d1d139b8cf0ae10b2bce1cb46d9af"
    private var cache: [String: URL] = [:]
    private let cacheLock = NSLock()
    
    private init() {}
    
    public func resolveTrailerStream(for item: MediaItem) async -> URL? {
        let cacheKey = "\(item.mediaType.rawValue)_\(item.id)"
        
        cacheLock.lock()
        if let cached = cache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        // Priority 1: Apple TV HLS direct master stream (HD / 4K with audio)
        if let hlsURL = await resolveAppleTVStream(tmdbId: item.id, isMovie: item.mediaType != .tvShow) {
            cacheLock.lock()
            cache[cacheKey] = hlsURL
            cacheLock.unlock()
            return hlsURL
        }
        
        // Priority 2: iTunes Store direct preview stream (.m4v with full audio)
        if let itunesURL = await resolveITunesPreviewStream(title: item.title, isMovie: item.mediaType != .tvShow) {
            cacheLock.lock()
            cache[cacheKey] = itunesURL
            cacheLock.unlock()
            return itunesURL
        }
        
        return nil
    }
    
    private func resolveAppleTVStream(tmdbId: Int, isMovie: Bool) async -> URL? {
        let endpoint = isMovie ? "movie" : "tv"
        let wikidataProp = isMovie ? "P9586" : "P9751"
        let urlString = "https://api.themoviedb.org/3/\(endpoint)/\(tmdbId)/external_ids?api_key=\(tmdbApiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.setValue("Anode/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let wikidataId = json["wikidata_id"] as? String, !wikidataId.isEmpty else {
                return nil
            }
            
            // Query Wikidata claim for Apple TV content ID
            let wikiURLString = "https://www.wikidata.org/w/api.php?action=wbgetclaims&entity=\(wikidataId)&property=\(wikidataProp)&format=json"
            guard let wikiURL = URL(string: wikiURLString) else { return nil }
            
            var wikiReq = URLRequest(url: wikiURL)
            wikiReq.timeoutInterval = 5
            wikiReq.setValue("Anode/1.0", forHTTPHeaderField: "User-Agent")
            
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
            appleReq.timeoutInterval = 6
            appleReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (appleHtmlData, _) = try await URLSession.shared.data(for: appleReq)
            guard let html = String(data: appleHtmlData, encoding: .utf8) else { return nil }
            
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
    
    private func resolveITunesPreviewStream(title: String, isMovie: Bool) async -> URL? {
        guard let escaped = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let searchURLString = "https://itunes.apple.com/search?term=\(escaped)&limit=10"
        guard let url = URL(string: searchURLString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return nil
            }
            
            let targetKind = isMovie ? "feature-movie" : "tv-episode"
            let sanitizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // First pass: match kind and title
            for result in results {
                let kind = result["kind"] as? String ?? ""
                let trackName = (result["trackName"] as? String ?? "").lowercased()
                
                if kind == targetKind && (trackName.contains(sanitizedTitle) || sanitizedTitle.contains(trackName)) {
                    if let previewStr = result["previewUrl"] as? String, let previewURL = URL(string: previewStr) {
                        return previewURL
                    }
                }
            }
            
            // Second pass: any feature-movie or tv-episode with previewUrl
            for result in results {
                let kind = result["kind"] as? String ?? ""
                if kind == targetKind {
                    if let previewStr = result["previewUrl"] as? String, let previewURL = URL(string: previewStr) {
                        return previewURL
                    }
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
