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
    @State var image: UIImage?

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
        if let uiImage = image {
            self.contentImage(Image(uiImage: uiImage))
        } else {
            self.placeholder()
                .task {
                    if image == nil, let url = imageUrl {
                        let task = getUIImage(url)
                        if let taskResult = try? await task.value {
                            let (taskImage, info) = taskResult
                            image = taskImage
                            self.cacheManager[url.absoluteString] = info
                        }
                    }
                }
        }
    }

    func getUIImage(_ url: URL) -> Task<(UIImage?, ImageCacheInfo?), Error> {
        let cacheInfo = self.cacheManager[url.absoluteString]

        return Task {
            // load from memory
            if let cacheInfo = cacheInfo {
                return (UIImage(data: cacheInfo.data), nil)
            }

            // fetch from DB
            let container = DataController.getCachedImageContainer
            let context = ModelContext(container)
            if let model = ImageService.getCachedImage(for: url, context),
               let imageData = model.imageData {
                return (UIImage(data: imageData), nil)
            }

            // fetch online
            let imageData = try await ImageService.loadImageData(url: url)
            let imageInfo = ImageCacheInfo(
                url: url,
                data: imageData
            )

            return (UIImage(data: imageData), imageInfo)
        }
    }
}
