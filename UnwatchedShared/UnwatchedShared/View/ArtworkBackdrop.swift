//
//  ArtworkBackdrop.swift
//  UnwatchedShared
//

import SwiftUI

/// Fills the space around square cover art sitting in a video-shaped thumbnail slot.
public struct ArtworkBackdrop: View {
    @Environment(ImageCacheManager.self) private var cacheManager

    private let imageUrls: [URL]
    @State private var backdrop: Backdrop?

    /// The same URLs the thumbnail loads from, tried in the same order.
    public init(urls: [URL?]) {
        let imageUrls = urls.compactMap { $0 }
        self.imageUrls = imageUrls
        _backdrop = State(initialValue: imageUrls.first.flatMap { Self.cache[$0.absoluteString] })
    }

    public var body: some View {
        Group {
            switch backdrop {
            case .color(let color):
                color
            case .blurredArt:
                CachedImageView(urls: imageUrls) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 16, opaque: true)
                } placeholder: {
                    Color.clear
                }
            case nil:
                Color.clear
            }
        }
        .task(id: imageUrls) {
            await resolve()
        }
    }

    private func resolve() async {
        guard backdrop == nil, let key = imageUrls.first?.absoluteString else { return }
        if let known = Self.cache[key] {
            backdrop = known
            return
        }
        for url in imageUrls {
            // the same task the thumbnail itself loads through: the image is decoded once
            let task = ImageService.getImage(url, cacheManager)
            guard let image = try? await task.value.0 else { continue }
            let resolved: Backdrop = await Task.detached(priority: .utility) {
                image.uniformEdgeColor().map { Backdrop.color($0) } ?? .blurredArt
            }.value
            Self.cache[key] = resolved
            backdrop = resolved
            return
        }
    }

    public enum Backdrop: Equatable, Sendable {
        case color(Color)
        case blurredArt
    }

    @MainActor private static var cache: [String: Backdrop] = [:]
}
