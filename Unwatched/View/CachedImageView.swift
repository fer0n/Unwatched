//
//  CachedThumbnailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct CachedImageView<Content, Content2>: View where Content: View, Content2: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager

    @State var imageTask: Task<ImageCacheInfo, Error>?

    var imageHolder: CachedImageHolder?
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)

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
        if let uiImage = getUIImage {
            self.contentImage(Image(uiImage: uiImage))
        } else {
            self.placeholder()
                .onAppear {
                    loadImage()
                }
                .task(id: imageTask) {
                    guard imageTask != nil,
                          let holderId = imageHolder?.persistentModelID else {
                        return
                    }
                    if let imageInfo = try? await imageTask?.value {
                        cacheManager[holderId] = imageInfo
                    }
                }
        }
    }

    func loadImage() {
        guard let holderId = imageHolder?.persistentModelID,
              let url = imageHolder?.thumbnailUrl,
              cacheManager[holderId] == nil else {
            return
        }
        imageTask = Task.detached {
            let imageData = try await ImageService.loadImageData(url: url)
            return ImageCacheInfo(
                url: url,
                data: imageData,
                holderId: holderId,
                uiImage: UIImage(data: imageData)
            )
        }
    }

    var getUIImage: UIImage? {
        if let imageData = imageHolder?.cachedImage?.imageData {
            return UIImage(data: imageData)
        }
        if let cacheInfo = cacheManager[imageHolder?.persistentModelID] {
            if let uiImage = cacheInfo.uiImage {
                return uiImage
            }
            return UIImage(data: cacheInfo.data)
        }
        return nil
    }
}
