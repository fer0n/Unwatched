//
//  ImageService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI
import OSLog

struct ImageService {
    static func persistImages(
        cache: [PersistentIdentifier: ImageCacheInfo],
        container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let context = ModelContext(container)
            cache.forEach { (holderId, info) in

                // Video
                if let video = context.model(for: holderId) as? Video {
                    if video.cachedImage != nil {
                        Logger.log.info("video !has image")
                        return
                    }
                    let imageCache = CachedImage(info.url, imageData: info.data)
                    context.insert(imageCache)
                    video.cachedImage = imageCache
                } else

                // Subscription
                if let sub = context.model(for: holderId) as? Subscription {
                    if sub.cachedImage != nil {
                        Logger.log.info("sub !has image")
                        return
                    }
                    let imageCache = CachedImage(info.url, imageData: info.data)
                    context.insert(imageCache)
                    sub.cachedImage = imageCache
                }

                Logger.log.info("saved")
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

    static func isYtShort(_ imageData: Data) -> Bool? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }

        // check if every xth pixel at the bottom is black
        let size = image.size

        // top and bottom of a regular video thumbnail is a black bar
        let width = size.width
        let height = size.height

        let topY = height / 30
        let topBottomY = height / 12

        let centerX = width / 2
        let xDist = width / 6

        let points: [CGPoint] = [
            // top      ° . °
            // image
            // bottom   . ° .

            CGPoint(x: centerX, y: topBottomY),
            CGPoint(x: centerX, y: height - topBottomY),

            CGPoint(x: centerX + xDist, y: topY),
            CGPoint(x: centerX - xDist, y: topY),

            CGPoint(x: centerX + xDist, y: height - topY),
            CGPoint(x: centerX - xDist, y: height - topY)
        ]

        let colors = image.pixelColors(at: points)
        for color in colors where !color.isBlack() {
            return true
        }
        return false
    }
}

// shorts detection
#Preview {
    // let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!
    let url = URL(string: "https://i3.ytimg.com/vi/jxmXQcYY1Sw/hqdefault.jpg")! // short

    guard let data = try? Data(contentsOf: url),
          let myImage = UIImage(data: data) else {
        return ZStack { }
    }
    let isShort = ImageService.isYtShort(data)

    let color = myImage.pixelColors(at: [CGPoint(x: 200, y: 200)])
    let isBlack = color[0].isBlack()

    return VStack {
        Image(uiImage: myImage)
        Text(verbatim: "IS BLACK: \(isBlack)")
        Text(verbatim: "IS BLACK: \(color)")
        Text(verbatim: "IS SHORT: \(isShort)")
    }
}
