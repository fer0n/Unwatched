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
                .task(id: imageUrl) {
                    if image == nil, let url = imageUrl {
                        let task = ImageService.getImage(url, cacheManager)
                        if let taskResult = try? await task.value {
                            let (taskImage, info) = taskResult
                            image = taskImage
                            self.cacheManager[url.absoluteString] = info
                        }
                    }
                }
        }
    }
}
