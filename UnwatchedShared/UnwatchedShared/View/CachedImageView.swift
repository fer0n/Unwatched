//
//  CachedThumbnailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

public struct CachedImageView<Content, Content2>: View where Content: View, Content2: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager

    var imageUrl: URL?
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)
    @State var image: PlatformImage?

    public init(
        imageUrl: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.imageUrl = imageUrl
        self.contentImage = content
        self.placeholder = placeholder
    }

    public var body: some View {
        if let platformImage = image {
            #if os(iOS) || os(tvOS)
            self.contentImage(Image(uiImage: platformImage))
            #elseif os(macOS)
            self.contentImage(Image(nsImage: platformImage))
            #endif
        } else {
            self.placeholder()
                .task {
                    if image == nil, let url = imageUrl {
                        let task = getImage(url)
                        if let taskResult = try? await task.value {
                            let (taskImage, info) = taskResult
                            image = taskImage
                            self.cacheManager[url.absoluteString] = info
                        }
                    }
                }
        }
    }

    func getImage(_ url: URL) -> Task<(PlatformImage?, ImageCacheInfo?), Error> {
        let cacheInfo = self.cacheManager[url.absoluteString]

        return Task {
            // load from memory
            if let cacheInfo = cacheInfo {
                #if os(iOS)
                return (UIImage(data: cacheInfo.data), nil)
                #elseif os(macOS)
                return (NSImage(data: cacheInfo.data), nil)
                #endif
            }

            // fetch from DB
            let container = DataProvider.shared.imageContainer
            let context = ModelContext(container)
            if let model = ImageService.getCachedImage(for: url, context),
               let imageData = model.imageData {
                #if os(iOS)
                return (UIImage(data: imageData), nil)
                #elseif os(macOS)
                return (NSImage(data: imageData), nil)
                #endif
            }

            // fetch online
            let imageData = try await ImageService.loadImageData(url: url)
            let imageInfo = ImageCacheInfo(
                url: url,
                data: imageData
            )

            #if os(iOS) || os(tvOS)
            return (UIImage(data: imageData), imageInfo)
            #elseif os(macOS)
            return (NSImage(data: imageData), imageInfo)
            #endif
        }
    }
}
