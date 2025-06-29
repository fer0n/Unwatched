//
//  ImageService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI
import OSLog

public struct ImageService {
    public static func persistImages(
        cache: [String: ImageCacheInfo]
    ) async {
        let container = DataProvider.shared.imageContainer
        let context = ModelContext(container)

        for info in cache.values {
            if info.persistImage == true {
                var color: Color?
                if info.persistColor == true {
                    color = info.color
                    Log.info("saved color with image for: \(info.url)")
                }
                let imageCache = CachedImage(info.url, imageData: info.data, color: color)
                context.insert(imageCache)
                Log.info("saved image with URL: \(info.url)")
            } else if info.persistColor == true, let color = info.color {
                guard let image = getCachedImage(for: info.url, context) else {
                    Log.error("Could not find image for URL: \(info.url)")
                    continue
                }
                Log.info("saved color for: \(info.url)")
                image.color = color
            }
        }

        try? context.save()
    }

    public static func storeImages(for infos: [NotificationInfo]) {
        let images = infos.compactMap { info in
            if let sendableVideo = info.video,
               let url = sendableVideo.thumbnailUrl,
               let data = sendableVideo.thumbnailData {
                return (url: url, data: data)
            }
            return nil
        }

        storeImages(images)
    }

    public static func storeImages(_ images: [(url: URL, data: Data)]) {
        Task.detached {
            let container = DataProvider.shared.imageContainer
            let context = ModelContext(container)

            for (url, data) in images {
                let image = CachedImage(url, imageData: data)
                context.insert(image)
            }
            try? context.save()
        }
    }

    public static func deleteImages(_ urls: [URL]) {
        Task {
            let imageContainer = DataProvider.shared.imageContainer
            let context = ModelContext(imageContainer)
            for url in urls {
                if let image = getCachedImage(for: url, context) {
                    context.delete(image)
                }
            }
            try? context.save()
        }
    }

    public static func getCachedImage(for url: URL, _ modelContext: ModelContext) -> CachedImage? {
        var fetch = FetchDescriptor<CachedImage>(predicate: #Predicate {
            $0.imageUrl == url
        })
        fetch.fetchLimit = 1
        return try? modelContext.fetch(fetch).first
    }

    public static func deleteAllImages() -> Task<(), Error> {
        return Task {
            let imageContainer = DataProvider.shared.imageContainer
            let context = ModelContext(imageContainer)
            let fetch = FetchDescriptor<CachedImage>()
            let images = try context.fetch(fetch)
            for image in images {
                context.delete(image)
            }
            try context.save()
        }
    }

    public static func loadImageData(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    public static func blackHorizontalBarsPoints(
        _ size: CGSize
    ) -> [CGPoint] {
        // check if image has a black bar on top and on the bottom
        // → indicates regular video

        // top and bottom of a regular video thumbnail is a black bar
        let width: Double = size.width
        let height: Double = size.height

        let topY: Double = height / 40.0
        let topBottomY: Double = height / 22.0

        let centerX: Double = width / 2.0
        let xDist: Double = width / 4.3

        let points: [CGPoint] = [
            // edge pixels should be in the very corner
            // top      . ° .
            // image
            // bottom   ° . °

            CGPoint(x: centerX, y: topY),
            CGPoint(x: centerX, y: height - topY),

            CGPoint(x: centerX + xDist, y: topBottomY),
            CGPoint(x: centerX - xDist, y: topBottomY),

            CGPoint(x: centerX + xDist, y: height - topBottomY),
            CGPoint(x: centerX - xDist, y: height - topBottomY)
        ]
        return points
    }

    public static func hasBlackHorizontalBars(_ colors: [Color]) -> Bool {
        for color in colors where !color.isBlack {
            return false
        }
        return true
    }

    public static func blackContentBorderPoints(
        _ size: CGSize
    ) -> [CGPoint] {
        // check if image has a black bar on top and on the bottom
        // → indicates regular video

        // top and bottom of a regular video thumbnail is a black bar
        let width: Double = size.width
        let height: Double = size.height

        let topBottomY: Double = height / 3.5

        let centerX: Double = width / 2.0
        let xDist: Double = width / 4.3
        let xGap: Double = width / 20.0

        let points: [CGPoint] = [
            // top      ..   ..
            // image
            // bottom   ..   ..
            // all 4 on the inside are black, all four are not
            // → likely horizontal image with black on top/bottom
            // which leads to black bars even though it's a short

            // if those are black..
            CGPoint(x: centerX - xDist + xGap, y: topBottomY),
            CGPoint(x: centerX + xDist - xGap, y: topBottomY),
            CGPoint(x: centerX - xDist + xGap, y: height - topBottomY),
            CGPoint(x: centerX + xDist - xGap, y: height - topBottomY),

            // ..and those are not black..
            CGPoint(x: centerX - xDist, y: topBottomY),
            CGPoint(x: centerX + xDist, y: topBottomY),
            CGPoint(x: centerX - xDist, y: height - topBottomY),
            CGPoint(x: centerX + xDist, y: height - topBottomY)

            // ..it's likely a black short thumbnail with a horizontal image in the center (streches background)
        ]
        return points
    }

    private static func hasBlackContentBorder(_ colors: [Color]) -> Bool {
        for i in 0..<4 where !colors[i].isBlack {
            return false
        }

        var allowBlackCount = 1
        for i in 4..<8 where colors[i].isBlack {
            allowBlackCount -= 1
            if allowBlackCount < 0 {
                return false
            }
        }
        return true
    }

    public static func isYtShort(_ imageData: Data) -> Bool? {
        #if os(macOS)
        guard let image = NSImage(data: imageData) else {
            return nil
        }
        #else
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        #endif

        let size = image.size
        let blackHorizontalBarsPoints = blackHorizontalBarsPoints(size)
        let blackHorizontalBarsPointsCount = blackHorizontalBarsPoints.count
        let blackContentBorderPoints = blackContentBorderPoints(size)
        let points = blackHorizontalBarsPoints + blackContentBorderPoints

        let colors = image.pixelColors(at: points)
        let blackHorizontalBarsColors = Array(colors[0..<blackHorizontalBarsPointsCount])
        let blackContentBorderColors = Array(colors[blackHorizontalBarsPointsCount..<points.count])

        let hasBlackBars = hasBlackHorizontalBars(blackHorizontalBarsColors)
        if !hasBlackBars {
            return true
        }

        let hasBlackContentBorder = hasBlackContentBorder(blackContentBorderColors)
        if hasBlackContentBorder {
            return true
        }

        return false
    }

    @MainActor
    public static func getImage(
        _ url: URL,
        _ cacheManager: ImageCacheManager
    ) -> Task<(PlatformImage?, ImageCacheInfo), Error> {
        let cacheInfo = cacheManager[url.absoluteString]

        return Task.detached {
            // load from memory
            if var cacheInfo {
                #if os(iOS)
                return (UIImage(data: cacheInfo.data), cacheInfo)
                #elseif os(macOS)
                return (NSImage(data: cacheInfo.data), cacheInfo)
                #endif
            }

            // fetch from DB
            let container = DataProvider.shared.imageContainer
            let context = ModelContext(container)
            if let model = ImageService.getCachedImage(for: url, context),
               let imageData = model.imageData {
                let imageInfo = ImageCacheInfo(
                    url: url,
                    data: imageData,
                    color: model.color,
                    persistImage: false,
                    persistColor: false
                )
                #if os(iOS)
                return (UIImage(data: imageData), imageInfo)
                #elseif os(macOS)
                return (NSImage(data: imageData), imageInfo)
                #endif
            }

            // fetch online
            let imageData = try await ImageService.loadImageData(url: url)
            let imageInfo = ImageCacheInfo(
                url: url,
                data: imageData,
                persistImage: true
            )

            #if os(iOS) || os(tvOS)
            return (UIImage(data: imageData), imageInfo)
            #elseif os(macOS)
            return (NSImage(data: imageData), imageInfo)
            #endif
        }
    }

    @MainActor
    public static func getAccentColor(from url: URL, _ imageCacheManager: ImageCacheManager) async -> Task<ImageCacheInfo?, Never> {
        let task = ImageService.getImage(
            url,
            imageCacheManager
        )

        return Task.detached {
            guard let value = try? await task.value else {
                Log.error("getAccentColor failed: \(url)")
                return nil
            }
            var info = value.1

            if info.color == nil {
                let image = value.0
                if let color = image?.extractVibrantAccentColor() {
                    info.color = color
                    info.persistColor = true
                } else {
                    Log.error("getAccentColor: no color for \(url)")
                }
            }
            return info
        }
    }
}

// shorts detection
#if os(iOS)
#Preview {
    // no short
    // let url = URL(string: "https://i2.ytimg.com/vi/9pVd8_bjl1o/hqdefault.jpg")!

    // short
    // let url = URL(string: "https://i1.ytimg.com/vi/DW488vU0DfA/hqdefault.jpg")!

    // no short
    // let url = URL(staticString: "https://i3.ytimg.com/vi/bexRHVRVc3s/hqdefault.jpg")

    // no short
    // let url = URL(string: "https://i3.ytimg.com/vi/bexRHVRVc3s/hqdefault.jpg")!
    let url = URL(string: "https://i1.ytimg.com/vi/Pt3dHmQPSCU/hqdefault.jpg")!

    // short
    // let url = URL(string: "https://i4.ytimg.com/vi/skdL0ePqErk/hqdefault.jpg")!

    // short
    // let url = URL(string: "https://i3.ytimg.com/vi/jxmXQcYY1Sw/hqdefault.jpg")!

    let data = try! Data(contentsOf: url)
    let myImage = UIImage(data: data)!
    let imgSize = myImage.size
    let points = ImageService.blackContentBorderPoints(imgSize)

    let isShort = ImageService.isYtShort(data)
    let isShortText = isShort == true ? "YES" : isShort == nil ? "UNKNOWN" : "NO"

    let point = points[7]

    let color = myImage.pixelColors(at: [point])

    let isBlack = color[0].isBlack
    let isBlackText = isBlack == true ? "YES" : "NO"
    let size: CGFloat = 14

    return VStack {
        Image(uiImage: myImage)
            .overlay {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.red)
                        .frame(width: size, height: size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: -size/2, y: -size/2)
                        .offset(x: point.x, y: point.y)
                }

                Circle()
                    .fill(Color.blue)
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: -size/2, y: -size/2)
                    .offset(x: point.x, y: point.y)
            }
            .padding()
        Text(verbatim: "IS BLACK: \(isBlackText)")
        Text(verbatim: "COLOR: \(color.debugDescription)")
        Text(verbatim: "IS SHORT: \(isShortText)")
    }
}
#endif
