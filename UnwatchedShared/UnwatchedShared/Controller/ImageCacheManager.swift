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

    public func removeAll() {
        cache.removeAllObjects()
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
