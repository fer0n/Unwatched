//
//  CachedThumbnailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct CachedImageView<Content, Content2>: View where Content: View, Content2: View {
    @Environment(\.modelContext) var modelContext
    @Environment(ImageCacheManager.self) var cacheManager
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
        }
    }

    func loadImage () {
        guard let video = video,
              let url = video.thumbnailUrl,
              cacheManager[url] == nil else {
            return
        }
        let videoId = video.persistentModelID
        let container = modelContext.container
        Task {
            let task = ImageService.loadImage(videoId, url: url, container: container)
            let uiImage = try? await task.value
            await MainActor.run {
                cacheManager[url] = uiImage
            }
        }
    }

    var getUIImage: UIImage? {
        if let imageData = video?.cachedImage?.imageData {
            return UIImage(data: imageData)
        }
        if let uiImage = cacheManager[video?.thumbnailUrl] {
            return uiImage
        }
        return nil
    }
}

// #Preview {
//    CachedImageView(video: Video.getDummy())
// }
