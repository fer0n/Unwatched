//
//  InboxCard.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// A single inbox video, shown as a card in the inbox card stack
struct InboxCard: View, Equatable {
    nonisolated static func == (lhs: InboxCard, rhs: InboxCard) -> Bool {
        lhs.content == rhs.content && lhs.layout == rhs.layout
    }

    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Environment(\.modelContext) private var modelContext

    let video: Video
    let layout: Layout
    private let content: Content

    @ScaledMetric private var titleSize = 19
    @ScaledMetric private var infoSize = 13
    @ScaledMetric(wrappedValue: InboxCardActionBar.buttonSize) private var actionBarSize
    @ScaledMetric private var durationRadius: CGFloat = 8
    @ScaledMetric private var durationPadding: CGFloat = 5
    @ScaledMetric private var durationFontSize: CGFloat = 16

    private static let cornerRadius: CGFloat = 28
    static let contentPadding: CGFloat = 14

    init(video: Video, layout: Layout) {
        self.video = video
        self.layout = layout
        self.content = Content(video: video)
    }

    var body: some View {
        layout.container {
            thumbnail
            details(video.sortedChapterData)
        }
        .background(Color.insetBackgroundColor)
        .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func details(_ chapters: [SendableChapter]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                title
                info

                if !chapters.isEmpty {
                    InboxCardChapters(video: video, chapters: chapters, bleedEdges: layout.chapterBleedEdges)
                }
            }

            description
                .layoutPriority(-1)
        }
        .padding(.horizontal, Self.contentPadding)
        .padding(.top, 12)
        .padding(.bottom, InboxCardActionBar.topPadding + actionBarSize + InboxCardActionBar.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openDetail)
    }

    private var thumbnail: some View {
        CachedImageView(urls: content.imageUrls) { image in
            // 4:3 thumbnails have black bars baked in, fill 16:9 first to crop them off
            Color.clear
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fill)
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
        } placeholder: {
            Color.backgroundColor
        }
        .frame(width: layout.mediaSize.width, height: layout.mediaSize.height)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            if video.duration != nil || video.isYtShort == true || video.noDuration == true {
                VideoListItemDurationOverlay(
                    video: video,
                    videoDuration: video.duration,
                    roughDuration: nil,
                    radius: durationRadius,
                    padding: durationPadding,
                    font: .system(size: durationFontSize)
                )
                .padding(10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: playVideo)
        .accessibilityElement()
        .accessibilityLabel("play")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, playVideo)
    }

    private var title: some View {
        Text(verbatim: content.title)
            .font(.system(size: titleSize, weight: .semibold))
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
            .frame(idealWidth: 200)
            .layoutPriority(2)
    }

    private var info: some View {
        HStack(spacing: 5) {
            if let subscriptionTitle = content.subscriptionTitle {
                Button(action: openChannel) {
                    Text(verbatim: subscriptionTitle)
                        .lineLimit(1)
                        .textCase(.uppercase)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(subscriptionTitle)
            }

            ForEach(content.details, id: \.self) { detail in
                Text(verbatim: Const.dotString)
                Text(verbatim: detail)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .font(.system(size: infoSize))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var description: some View {
        if let description = content.description {
            CollapsingDescriptionLayout(spacing: 10) {
                Text(verbatim: description)
                    .font(.system(size: infoSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1...)
            }
            .clipped()
        }
    }

    private func playVideo() {
        VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        player.playVideo(video)
        navManager.handlePlay()
        Signal.videoAction("play", .inboxCards)
        Signal.playbackStarted(VideoListContext.inboxCards.rawValue)
    }

    private func openDetail() {
        navManager.videoDetail = video
        video.isNew = false
    }

    private func openChannel() {
        if let subscription = video.subscription {
            navManager.pushSubscription(subscription: subscription)
        }
    }

    /// Everything the card shows, read from the video once per update instead of during layout
    private struct Content: Equatable {
        /// more than can fit onto a card
        static let descriptionLimit = 600

        let title: String
        let subscriptionTitle: String?
        let description: String?
        let details: [String]
        let imageUrls: [URL?]
        /// Not shown, keeps `==` from missing chapters that arrive after the card was built
        let chapterCount: Int

        init(video: Video) {
            title = video.title.isEmpty ? video.youtubeId : video.title
            subscriptionTitle = video.subscriptionData?.displayTitle

            if let text = video.videoDescription, !text.isEmpty {
                description = String(text.prefix(Self.descriptionLimit))
            } else {
                description = nil
            }

            var details = [String]()
            if let published = video.publishedDate {
                details.append(published.formattedRelative)
            }
            self.details = details

            imageUrls = [
                UrlService.getImageUrl(video.thumbnailUrl, .large),
                UrlService.getImageUrl(video.thumbnailUrl, .medium)
            ]
            chapterCount = (video.chapters?.count ?? 0) + (video.mergedChapters?.count ?? 0)
        }
    }
}

private func dummyLayout(_ size: CGSize) -> InboxCard.Layout {
    InboxCard.Layout(available: size, minDetailHeight: InboxCard.Layout.baseDetailHeight)
}

#Preview {
    let size = CGSize(width: 350, height: 500)

    InboxCard(video: DataProvider.dummyVideo, layout: dummyLayout(size))
        .previewEnvironments()
        .frame(width: size.width, height: size.height)
        .padding()
        .background(Color.backgroundColor)
}

#Preview("landscape") {
    let size = CGSize(width: 780, height: 300)

    InboxCard(video: DataProvider.dummyVideo, layout: dummyLayout(size))
        .previewEnvironments()
        .frame(width: size.width, height: size.height)
        .padding()
        .background(Color.backgroundColor)
}
