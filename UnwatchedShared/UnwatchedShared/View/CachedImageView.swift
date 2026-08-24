//
//  CachedThumbnailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog


/// A view that asynchronously loads, caches, and displays an image
public struct CachedImageView<Content, Content2>: View where Content: View, Content2: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager

    var imageUrls: [URL]
    var maxPixelSize: CGFloat
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)
    @State var image: PlatformImage?

    /// Creates a cached image view that tries to load images from the provided URLs in order.
    public init(
        urls: [URL?],
        maxPixelSize: CGFloat = Const.maxDecodedImagePixelSize,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        let imageUrls = urls.compactMap { $0 }
        self.imageUrls = imageUrls
        self.maxPixelSize = maxPixelSize
        self.contentImage = content
        self.placeholder = placeholder
        // loading is asynchronous even for an already decoded image, a view recreated around one
        // would blank for a frame
        _image = State(
            initialValue: imageUrls.lazy
                .compactMap { ImageService.decodedImageCache[ImageService.decodedCacheKey(url: $0, maxPixelSize: maxPixelSize)] }
                .first
        )
    }

    public init(
        imageUrl: URL?,
        maxPixelSize: CGFloat = Const.maxDecodedImagePixelSize,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.init(urls: [imageUrl], maxPixelSize: maxPixelSize, content: content, placeholder: placeholder)
    }

    public var body: some View {
        Group {
            if let platformImage = image {
#if os(iOS) || os(tvOS) || os(visionOS)
                self.contentImage(Image(uiImage: platformImage))
#elseif os(macOS)
                self.contentImage(Image(nsImage: platformImage))
#endif
            } else {
                self.placeholder()
                    .task(id: imageUrls) {
                        await loadImage()
                    }
            }
        }
        .onChange(of: imageUrls) {
            Task {
                await loadImage()
            }
        }
        .onChange(of: maxPixelSize) {
            Task {
                await loadImage()
            }
        }
    }

    func loadImage() async {
        for url in imageUrls {
            let task = ImageService.getImage(url, cacheManager, maxPixelSize: maxPixelSize)
            if let taskResult = try? await task.value {
                let (taskImage, info) = taskResult
                image = taskImage
                self.cacheManager[url.absoluteString] = info
                return
            }
        }
    }
}
