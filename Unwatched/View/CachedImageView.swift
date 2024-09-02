//
//  CachedThumbnailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct CachedImageView<Content, Content2>: View where Content: View, Content2: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager

    var imageHolder: CachedImageHolder?
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)
    @State var image: UIImage?

    init(
        imageHolder: CachedImageHolder?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.imageHolder = imageHolder
        self.contentImage = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let uiImage = image {
            self.contentImage(Image(uiImage: uiImage))
        } else {
            self.placeholder()
                .task {
                    if image == nil, let url = imageHolder?.thumbnailUrl {
                        let task = getUIImage(url, cacheManager.container)
                        image = try? await task.value
                    }
                }
        }
    }

    func getUIImage(_ url: URL, _ container: ModelContainer?) -> Task<UIImage?, Error> {
        Task.detached {
            // fetch from DB
            if let container = container {
                let context = ModelContext(container)
                if let model = ImageService.getCachedImage(for: url, context),
                   let imageData = model.imageData {
                    return UIImage(data: imageData)
                }
            } else {
                Logger.log.warning("ImageCacheManager has no container set, images are not peristed")
            }

            // load from memory
            if let cacheInfo = self.cacheManager[url.absoluteString] {
                return UIImage(data: cacheInfo.data)
            }

            // fetch online
            let imageData = try await ImageService.loadImageData(url: url)
            let imageInfo = ImageCacheInfo(
                url: url,
                data: imageData
            )
            self.cacheManager[url.absoluteString] = imageInfo

            return UIImage(data: imageData)
        }
    }
}
