//
//  ImageCacheManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "ImageCacheManager")

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
            self.cache = [:]
        } catch {
            log.error("error while trying to persist cache: \(error)")
        }
    }
}

struct ImageCacheInfo {
    var url: URL
    var data: Data
    var holderId: PersistentIdentifier
    var uiImage: UIImage?
}
