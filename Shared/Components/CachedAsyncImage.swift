import SwiftUI
import UIKit

// MARK: - Dedicated In-Memory and Disk Image Cache Service

@MainActor
public final class ImageCacheService: ObservableObject {
    public static let shared = ImageCacheService()
    
    private let memoryCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 400
        cache.totalCostLimit = 200 * 1024 * 1024 // 200 MB in RAM
        return cache
    }()
    
    private var activeTasks: [URL: Task<UIImage?, Never>] = [:]
    
    public init() {}
    
    public func image(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }
    
    public func storeImage(_ image: UIImage, for url: URL, cost: Int = 0) {
        memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    public func loadImage(from url: URL) async -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        
        if let existing = activeTasks[url] {
            return await existing.value
        }
        
        let task = Task<UIImage?, Never> { () -> UIImage? in
            defer {
                Task { @MainActor in
                    self.activeTasks.removeValue(forKey: url)
                }
            }
            
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 15
            
            for attempt in 1...2 {
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let uiImage = UIImage(data: data) {
                    let cost = data.count
                    await MainActor.run {
                        self.memoryCache.setObject(uiImage, forKey: url as NSURL, cost: cost)
                    }
                    return uiImage
                }
                
                if attempt == 1 {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
            }
            
            return nil
        }
        
        activeTasks[url] = task
        return await task.value
    }
}

// MARK: - Resilient Cached Async Image Component

public struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    
    @State private var loadedImage: UIImage?
    @State private var loadFailed: Bool = false
    
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
        if let url, let cached = ImageCacheService.shared.image(for: url) {
            _loadedImage = State(initialValue: cached)
        }
    }
    
    public var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loadFailed || url == nil {
                ZStack {
                    Color(white: 0.10)
                    Image(systemName: "film")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                }
            } else {
                Color(white: 0.12)
            }
        }
        .task(id: url) {
            guard let url else {
                loadFailed = true
                return
            }
            
            if let cached = ImageCacheService.shared.image(for: url) {
                self.loadedImage = cached
                self.loadFailed = false
                return
            }
            
            if let fetched = await ImageCacheService.shared.loadImage(from: url) {
                withAnimation(.easeInOut(duration: 0.20)) {
                    self.loadedImage = fetched
                    self.loadFailed = false
                }
            } else {
                self.loadFailed = true
            }
        }
    }
}
