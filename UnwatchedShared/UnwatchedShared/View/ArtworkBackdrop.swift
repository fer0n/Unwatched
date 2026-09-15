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
            case .gradient(let edge, let center):
                LinearGradient(colors: [edge, center, edge], startPoint: .leading, endPoint: .trailing)
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
        guard let key = imageUrls.first?.absoluteString else { return }
        if let known = Self.cache[key] {
            backdrop = known
            return
        }
        for url in imageUrls {
            // the same task the thumbnail itself loads through: the image is decoded once
            let task = ImageService.getImage(url, cacheManager)
            guard let image = try? await task.value.0 else { continue }
            // a 12x12 downsample and 44 pixels: a task hop off the main thread costs more than the work
            let resolved = image.uniformEdgeColors()
                .map { Backdrop.gradient(edge: $0.edge, center: $0.center) } ?? .blurredArt
            Self.cache[key] = resolved
            backdrop = resolved
            return
        }
    }

    public enum Backdrop: Equatable, Sendable {
        case gradient(edge: Color, center: Color)
        case blurredArt
    }

    @MainActor private static var cache: [String: Backdrop] = [:]
}
