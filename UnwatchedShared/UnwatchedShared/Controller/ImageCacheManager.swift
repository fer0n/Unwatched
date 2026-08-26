//
//  ImageCacheManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog

/// Holds images in memory until `persistCache()` is called.
///
/// This avoids performance issues when saving data.
@Observable public class ImageCacheManager {
    @MainActor
    public static let shared: ImageCacheManager = {
        ImageCacheManager()
    }()

    private var cache = [String: ImageCacheInfo]()
    public init() { }

    public subscript(id: String?) -> ImageCacheInfo? {
        get {
            guard let id else { return nil }
            return cache[id]
        }
        set {
            guard let id else { return }
            if let value = newValue {
                cache[id] = value
            }
        }
    }

    @MainActor
    public func persistCache() async {
        let cache = cache
        await ImageService.persistImages(
            cache: cache
        )
        clearCacheAll()
    }

    public func clearCacheAll() {
        cache = [:]
    }

    public func clearCache(_ imageUrl: String) {
        cache[imageUrl] = nil
    }
    
    @MainActor
    public func clearMemory() async {
        await persistCache()
    }
}

/// Thread-safe in-memory cache of **decoded** images, keyed by URL string.
///
/// `ImageCacheManager` only buffers raw image `Data` awaiting persistence, so without this
/// every `ImageService.getImage` call re-runs `PlatformImage(data:)` — re-decoding the same
/// bytes each time a cell is recycled while scrolling. `NSCache` is thread-safe and evicts
/// automatically under memory pressure, bounded here by `totalCostLimit`.
public final class DecodedImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, PlatformImage>()
    private let lock = NSLock()
    /// The sizes each URL has been decoded at, so a request for a smaller one can be scaled from a bigger bitmap
    /// that's already in hand. `NSCache` can't be enumerated and evicts on its own, so this is a hint, not a
    /// record: a size named here may no longer be cached, and the lookup below simply misses.
    private var sizesByUrl = [String: Set<Int>]()

    public init(totalCostLimit: Int = 100 * 1024 * 1024) {
        cache.totalCostLimit = totalCostLimit
    }

    public subscript(key: String) -> PlatformImage? {
        get { cache.object(forKey: key as NSString) }
        set {
            guard let newValue else {
                cache.removeObject(forKey: key as NSString)
                return
            }
            cache.setObject(newValue, forKey: key as NSString, cost: newValue.decodedByteCost)
        }
    }

    /// Stores a decode and remembers the size it was made at.
    public func store(_ image: PlatformImage, url: String, maxPixelSize: Int) {
        self[Self.key(url, maxPixelSize)] = image
        lock.withLock { sizesByUrl[url, default: []].insert(maxPixelSize) }
    }

    public static func key(_ url: String, _ maxPixelSize: Int) -> String {
        "\(url)#\(maxPixelSize)"
    }

    /// The smallest cached decode of `url` that is still at least `maxPixelSize` across — scaling one of those down
    /// is far cheaper than decoding the source again, which for an episode cover means re-reading a 3000px JPEG.
    public func smallestAtLeast(url: String, maxPixelSize: Int) -> PlatformImage? {
        let candidates = lock.withLock { sizesByUrl[url] ?? [] }
            .filter { $0 > maxPixelSize }
            .sorted()
        for size in candidates {
            if let image = self[Self.key(url, size)] {
                return image
            }
        }
        return nil
    }

    /// Every decoded size of one URL. The plain subscript can't do this: its keys carry the size they were decoded
    /// at, so passing a bare URL there removes nothing.
    public func removeAll(url: String) {
        let sizes = lock.withLock { sizesByUrl.removeValue(forKey: url) ?? [] }
        for size in sizes {
            self[Self.key(url, size)] = nil
        }
    }

    public func removeAll() {
        cache.removeAllObjects()
        lock.withLock { sizesByUrl.removeAll() }
    }
}

public struct ImageCacheInfo: Sendable {
    public var url: URL
    public var data: Data
    public var color: Color?
    public var persistImage: Bool
    public var persistColor: Bool

    public init(
        url: URL,
        data: Data,
        color: Color? = nil,
        persistImage: Bool = true,
        persistColor: Bool = true
    ) {
        self.url = url
        self.data = data
        self.color = color
        self.persistImage = persistImage
        self.persistColor = persistColor
    }
}
