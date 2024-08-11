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
    private var cache: [PersistentIdentifier: ImageCacheInfo] = [:]
    subscript(id: PersistentIdentifier?) -> ImageCacheInfo? {
        get {
            guard let id else { return nil }
            return cache[id]
        }
        set {
            guard let id else { return }
            cache[id] = newValue
        }
    }

    func persistCache(_ container: ModelContainer) async {
        let cache = cache
        let task = ImageService.persistImages(cache: cache, container: container)
        do {
            try await task.value
            clearCacheAll()
        } catch {
            Logger.log.error("error while trying to persist cache: \(error)")
        }
    }

    func clearCacheAll() {
        self.cache = [:]
    }

    func clearCache(holderId: PersistentIdentifier) {
        cache[holderId] = nil
    }
}

struct ImageCacheInfo {
    var url: URL
    var data: Data
    var holderId: PersistentIdentifier
    var uiImage: UIImage?
}
