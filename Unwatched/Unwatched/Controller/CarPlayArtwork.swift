//
//  CarPlayArtwork.swift
//  Unwatched
//

#if os(iOS)
import CarPlay
import UnwatchedShared

@MainActor
final class CarPlayArtwork {
    var displayScale: CGFloat = 2
    private let cache = NSCache<NSURL, UIImage>()
    private var loads: [URL: Task<UIImage?, Never>] = [:]

    static func url(for video: Video) -> URL? {
        // mqdefault is 16:9, without hqdefault's black bars
        UrlService.getImageUrl(video.displayThumbnailUrl, .small)
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let image = cached(url) {
            return image
        }
        return await task(for: url).value
    }

    func preload(_ urls: [URL], timeout: Double = 1) async {
        let pending = urls.filter { cached($0) == nil }
        pending.forEach { _ = task(for: $0) }
        _ = await Poll.until(timeout: timeout, step: 0.05) {
            pending.allSatisfy { loads[$0] == nil } ? .done : .retry
        }
    }

    private func task(for url: URL) -> Task<UIImage?, Never> {
        if let load = loads[url] {
            return load
        }
        let size = CPListItem.maximumImageSize
        let maxPixelSize = max(size.width, size.height) * max(displayScale, 1)
        let load = Task { [weak self] in
            let image = await Self.decode(url, maxPixelSize: maxPixelSize)
            if let image {
                self?.cache.setObject(image, forKey: url as NSURL)
            }
            self?.loads[url] = nil
            return image
        }
        loads[url] = load
        return load
    }

    nonisolated private static func decode(_ url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        guard let data = await ImageService.imageData(for: url) else {
            return nil
        }
        return UIImage(downsampling: data, maxPixelSize: maxPixelSize)
    }
}
#endif
