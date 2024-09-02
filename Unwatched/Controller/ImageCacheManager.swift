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
@Observable class ImageCacheManager {
    weak var container: ModelContainer?

    private var cacheKeys = Set<String>()

    private var cache = NSCache<NSString, ImageCacheInfo>()
    subscript(id: String?) -> ImageCacheInfo? {
        get {
            guard let id else { return nil }
            return cache.object(forKey: (id as NSString))
        }
        set {
            guard let id else { return }
            if let value = newValue {
                cacheKeys.insert(id)
                cache.setObject(value, forKey: (id as NSString))
            }
        }
    }

    func persistCache() async {
        let cache = cache
        guard let container = container else {
            Logger.log.warning("No container to persist images")
            return
        }
        ImageService.persistImages(
            cache: cache,
            cacheKeys: cacheKeys,
            imageContainer: container
        )
        clearCacheAll()
    }

    func clearCacheAll() {
        cache.removeAllObjects()
    }

    func clearCache(_ imageUrl: String) {
        cache.removeObject(forKey: imageUrl as NSString)
    }
}

class ImageCacheInfo {
    var url: URL
    var data: Data

    init(url: URL, data: Data) {
        self.url = url
        self.data = data
    }
}
