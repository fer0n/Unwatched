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
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)
    @State var image: PlatformImage?

    /// Creates a cached image view that tries to load images from the provided URLs in order.
    ///
    /// - Parameters:
    ///   - urls: Image URLs that will be tried in order until one loads successfully.
    ///   - content: A closure that creates the content of this stack.
    ///   - placeholder: A closure that creates the placeholder view while the image is loading.
    public init(
        urls: [URL?],
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.imageUrls = urls.compactMap { $0 }
        self.contentImage = content
        self.placeholder = placeholder
    }

    public init(
        imageUrl: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.init(urls: [imageUrl], content: content, placeholder: placeholder)
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
    }
    
    func loadImage() async {
        for url in imageUrls {
            let task = ImageService.getImage(url, cacheManager)
            if let taskResult = try? await task.value {
                let (taskImage, info) = taskResult
                image = taskImage
                self.cacheManager[url.absoluteString] = info
                return
            }
        }
    }
}
