//
//  ImageCacheManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData

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

    func persistCache(_ container: ModelContainer) {
        let cache = cache
        Task {
            let task = ImageService.persistImages(cache: cache, container: container)
            try await task.value
            await MainActor.run {
                self.cache = [:]
            }
        }

    }
}

struct ImageCacheInfo {
    var url: URL
    var data: Data
    var videoId: PersistentIdentifier
    var uiImage: UIImage?
}
