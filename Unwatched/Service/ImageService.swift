//
//  ImageService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI

class ImageService {

    static func persistImages(
        cache: [PersistentIdentifier: ImageCacheInfo],
        container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let context = ModelContext(container)
            cache.forEach { (holderId, info) in

                // Video
                if let video = context.model(for: holderId) as? Video {
                    if video.cachedImage != nil {
                        print("video !has image")
                        return
                    }
                    let imageCache = CachedImage(info.url, imageData: info.data)
                    context.insert(imageCache)
                    video.cachedImage = imageCache
                } else

                // Subscription
                if let sub = context.model(for: holderId) as? Subscription {
                    if sub.cachedImage != nil {
                        print("sub !has image")
                        return
                    }
                    let imageCache = CachedImage(info.url, imageData: info.data)
                    context.insert(imageCache)
                    sub.cachedImage = imageCache
                }

                print("saved")
            }
            try context.save()
        }
        return task
    }

    static func deleteAllImages(_ container: ModelContainer) -> Task<(), Error> {
        return Task {
            let context = ModelContext(container)
            let fetch = FetchDescriptor<CachedImage>()
            let images = try context.fetch(fetch)
            for image in images {
                context.delete(image)
            }
            try context.save()
        }
    }

    static func loadImageData(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}
