//
//  ArtworkFill.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// A video's artwork filling whatever space it is given, with YouTube's letterboxing cropped off.
///
/// The 16:9 box is pinned *before* the image fills it, and that order is the whole point:
/// `hqdefault` is a 4:3 image with the frame letterboxed inside it, so filling a square or a
/// portrait container directly scales the image by its height and puts the black bars on screen.
/// Covering the container with a 16:9 box instead lands on the picture, which is how
/// `VideoListItemThumbnail` crops them in the app.
///
/// Podcast cover art is genuinely square, has no bars to crop, and would lose its top and bottom to
/// that pass — so it fills the container directly.
struct ArtworkFill: View {
    let url: URL?
    let isSquare: Bool
    var maxPixelSize: CGFloat = 320

    var body: some View {
        Color.clear
            .overlay {
                if isSquare {
                    image
                } else {
                    Color.clear
                        .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fill)
                        .overlay { image }
                }
            }
            .clipped()
    }

    private var image: some View {
        CachedImageView(urls: [url], maxPixelSize: maxPixelSize) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Color.clear
        }
    }
}
