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

    var video: Video?
    private let contentImage: ((Image) -> Content)
    private let placeholder: (() -> Content2)

    init(
        video: Video?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Content2
    ) {
        self.video = video
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
                          let videoId = video?.persistentModelID else {
                        return
                    }
                    if let imageInfo = try? await imageTask?.value {
                        cacheManager[videoId] = imageInfo
                    }
                }
        }
    }

    func loadImage() {
        guard let video = video,
              let url = video.thumbnailUrl,
              cacheManager[video.persistentModelID] == nil else {
            return
        }
        let videoId = video.persistentModelID
        imageTask = Task.detached {
            let imageData = try await ImageService.loadImageData(url: url)
            return ImageCacheInfo(
                url: url,
                data: imageData,
                videoId: videoId,
                uiImage: UIImage(data: imageData)
            )
        }
    }

    var getUIImage: UIImage? {
        if let imageData = video?.cachedImage?.imageData {
            return UIImage(data: imageData)
        }
        if let cacheInfo = cacheManager[video?.persistentModelID] {
            if let uiImage = cacheInfo.uiImage {
                return uiImage
            }
            return UIImage(data: cacheInfo.data)
        }
        return nil
    }
}

// #Preview {
//    CachedImageView(video: Video.getDummy())
// }
