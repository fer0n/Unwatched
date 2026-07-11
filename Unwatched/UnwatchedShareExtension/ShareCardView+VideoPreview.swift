//
//  ShareCardView+VideoPreview.swift
//  UnwatchedShareExtension
//

import SwiftUI
import UnwatchedShared

extension ShareCardView {
    /// Thumbnail, title, and description — scrolls as one unit, with the action buttons floating
    /// on top via `.safeAreaInset`, same grouping as the video detail sheet's ScrollView.
    @ViewBuilder
    func videoPreviewContent(for video: SendableVideo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            shareVideoThumbnail(for: video)
                .padding(.top, 10)
            videoTitleText(for: video)
                .padding(.horizontal, 10)
            descriptionText(for: video)
                .padding(.horizontal, 10)

        }
        .padding(.horizontal, 10)
    }

    /// Same recipe as the main app's `VideoDetailThumbnail`: a plain thumbnail image with
    /// concentric corners, no duration/progress overlay. Tapping it plays the video in-app, same
    /// as the Play button.
    func shareVideoThumbnail(for video: SendableVideo) -> some View {
        Button {
            onSelect(.play)
        } label: {
            CachedImageView(
                urls: [
                    ThumbnailUrlService.getImageUrl(video.thumbnailUrl, .large),
                    ThumbnailUrlService.getImageUrl(video.thumbnailUrl, .medium)
                ]
            ) { image in
                Color.clear
                    .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
                    .overlay {
                        image
                            .resizable()
                            .scaledToFill()
                    }
            } placeholder: {
                Color.shareSheetInsetBackground
                    .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
            }
            .clipShape(ConcentricRectangle(corners: .concentric(minimum: 25), isUniform: true))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(model.loadingAction != nil)
        .accessibilityLabel(ShareAction.play.title)
    }

    @ViewBuilder
    func videoTitleText(for video: SendableVideo) -> some View {
        Group {
            if !video.title.isEmpty {
                Text(video.title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .fontWidth(.compressed)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            } else {
                Text("loading")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fontWidth(.compressed)
                    .redacted(reason: .placeholder)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func descriptionText(for video: SendableVideo) -> some View {
        if let description = video.videoDescription, !description.isEmpty {
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var skeletonVideoPreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConcentricRectangle(corners: .concentric(minimum: 25), isUniform: true)
                .fill(Color.shareSheetInsetBackground)
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
                .padding(.top, 10)
            Text("loading")
                .font(.title)
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .redacted(reason: .placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 10)
    }
}
