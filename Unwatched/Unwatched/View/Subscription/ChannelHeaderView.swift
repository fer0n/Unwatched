//
//  ChannelHeaderView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Shared visual header for a channel/subscription: big condensed title, circular
/// image, and the channel meta line. Used by both the persisted subscription detail
/// (`SubscriptionInfoDetails`) and the non-persisted Search channel preview so they
/// look identical.
struct ChannelHeaderView: View {
    let title: String
    let imageUrl: URL?
    var userName: String?
    var author: String?
    var videoCount: Int?
    var onAuthorTap: (() -> Void)?
    /// Reserve the circular image slot even before `imageUrl` is known, so the layout
    /// doesn't jump when an avatar is loaded asynchronously (used by the Search preview).
    var reserveImage: Bool = false

    #if os(visionOS)
    let padding: CGFloat = 0
    #else
    let padding: CGFloat = 15
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if !os(visionOS)
            Text(title)
                .font(.system(size: 42))
                .fontWidth(.condensed)
                .fontWeight(.heavy)
                .padding(.horizontal, padding)
            #endif

            headerDetails
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var headerDetails: some View {
        let hasImage = imageUrl != nil || reserveImage

        HStack {
            if hasImage {
                avatar
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: hasImage ? 5 : 0) {
                if let userName {
                    Text(verbatim: "@\(userName)")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                if let author {
                    Text(verbatim: author)
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .onTapGesture {
                            onAuthorTap?()
                        }
                }

                if let availableVideosText {
                    let hasOtherInfos = userName != nil || hasImage || author != nil
                    Text(availableVideosText)
                        .font(.system(size: 14))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.leading, hasOtherInfos ? 0 : 10)
                }
            }
        }
        .padding(.bottom, 10)
        .padding(.horizontal, padding)
    }

    @ViewBuilder var avatar: some View {
        if let imageUrl {
            CachedImageView(imageUrl: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.insetBackgroundColor
            }
        } else {
            // Reserved placeholder while the avatar loads.
            Color.insetBackgroundColor
        }
    }

    private var availableVideosText: String? {
        guard let videoCount else { return nil }
        return String(
            AttributedString(localized: "^[\(videoCount) video](inflect: true) available").characters
        )
    }
}
