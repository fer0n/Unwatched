//
//  ImageService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI

class ImageService {
    static func loadImage(_ videoId: PersistentIdentifier,
                          url: URL,
                          container: ModelContainer) -> Task<UIImage?, Error> {
        let task = Task.detached {
            let imageData = try await self.loadImageData(url: url)
            let uiImg = UIImage(data: imageData)
            let context = ModelContext(container)
            guard let video = context.model(for: videoId) as? Video else {
                return nil as UIImage?
            }
            if video.cachedImage != nil {
                print("!has image")
                return nil as UIImage?
            }
            let imageCache = CachedImage(url, imageData: imageData)
            context.insert(imageCache)
            video.cachedImage = imageCache
            print("saved")
            return uiImg
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
