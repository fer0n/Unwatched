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
    private var cache = [String: ImageCacheInfo]()
    subscript(id: String?) -> ImageCacheInfo? {
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

    func persistCache() async {
        let cache = cache
        await ImageService.persistImages(
            cache: cache
        )
        clearCacheAll()
    }

    func clearCacheAll() {
        cache = [:]
    }

    func clearCache(_ imageUrl: String) {
        cache[imageUrl] = nil
    }
}

struct ImageCacheInfo {
    var url: URL
    var data: Data
}
