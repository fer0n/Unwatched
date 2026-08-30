//
//  TagVideosView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// Every video a tag shows.
struct TagVideosView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tag.order) private var tags: [Tag]

    @State private var videoListVM = VideoListVM(listId: "tagVideos")

    let tag: Tag

    var body: some View {
        let membership = self.membership

        ZStack {
            MyBackgroundColor()

            if membership.isEmpty || videoListVM.hasNoVideos {
                ContentUnavailableView("noVideosYet",
                                       systemImage: tag.displaySymbol,
                                       description: Text("noVideosForTagDescription"))
            } else {
                VideosViewAsync(
                    videoListVM: $videoListVM,
                    sorting: [SortDescriptor<Video>(\.publishedDate, order: .reverse)],
                    filter: membership.filter
                )
            }
        }
        .concentricMacWorkaround()
        .myNavigationTitle(.verbatim(tag.name))
        .onChange(of: membership) { _, newMembership in
            videoListVM.filter = newMembership.filter
            Task {
                await videoListVM.updateData(force: true)
            }
        }
    }

    private var membership: TagMembership {
        switch tag.mode {
        case .include:
            TagMembership(
                subscriptionIds: (tag.subscriptions ?? []).map(\.persistentModelID),
                addedVideoIds: (tag.videos ?? []).map(\.youtubeId)
            )
        case .exclude:
            TagMembership(
                subscriptionIds: (tag.subscriptions ?? []).map(\.persistentModelID),
                removedVideoIds: (tag.videos ?? []).map(\.youtubeId),
                isExcluding: true
            )
        case .untagged:
            TagMembership(
                subscriptionIds: Tag.coveredSubscriptions(tags).map(\.persistentModelID),
                removedVideoIds: Tag.coveredVideos(tags).map(\.youtubeId),
                isExcluding: true
            )
        }
    }
}

/// The videos a tag names one by one, as a regular video list.
struct TaggedVideosList: View {
    @State private var videoListVM = VideoListVM(listId: "taggedVideos")

    let title: LocalizedStringKey
    let tag: Tag

    var body: some View {
        let videoIds = (tag.videos ?? []).map(\.youtubeId)

        ZStack {
            MyBackgroundColor()

            if videoIds.isEmpty {
                ContentUnavailableView("noVideosYet",
                                       systemImage: tag.displaySymbol,
                                       description: Text("noVideosForTagDescription"))
            } else {
                VideosViewAsync(
                    videoListVM: $videoListVM,
                    sorting: [SortDescriptor<Video>(\.publishedDate, order: .reverse)],
                    filter: Self.filter(videoIds)
                )
            }
        }
        .concentricMacWorkaround()
        .myNavigationTitle(title)
        .onChange(of: videoIds) { _, newIds in
            videoListVM.filter = Self.filter(newIds)
            Task {
                await videoListVM.updateData(force: true)
            }
        }
    }

    private static func filter(_ videoIds: [String]) -> Predicate<Video>? {
        VideoListView.getVideoFilter(subscriptionIds: [], addedVideoIds: videoIds)
    }
}

/// One value so the view can watch it for changes in a single `onChange`.
struct TagMembership: Equatable {
    var subscriptionIds: [PersistentIdentifier] = []
    var addedVideoIds: [String] = []
    var removedVideoIds: [String] = []
    var isExcluding: Bool = false

    /// A subtractive tag always shows whatever it hasn't taken away.
    var isEmpty: Bool {
        !isExcluding && subscriptionIds.isEmpty && addedVideoIds.isEmpty
    }

    var filter: Predicate<Video>? {
        VideoListView.getVideoFilter(
            subscriptionIds: subscriptionIds,
            addedVideoIds: addedVideoIds,
            removedVideoIds: removedVideoIds,
            isExcluding: isExcluding
        )
    }
}

#Preview {
    TagVideosView(tag: Tag(name: "Tech"))
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
