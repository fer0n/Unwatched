//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct QueueView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false
    @AppStorage(Const.showVideoListOrder) var showVideoListOrder: Bool = false

    @Environment(NavigationManager.self) private var navManager

    var queue: [QueueEntry]
    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                if queue.isEmpty {
                    QueueViewUnavailable()
                    InboxHasEntriesTip()
                }
                // Potential Workaround: always showing the list might avoid a crash
                List {
                    EmptyView()
                        .id(NavigationManager.getScrollId("top", ClearList.queue.rawValue))

                    ForEach(queue) { entry in
                        ZStack {
                            if let video = entry.video {
                                VideoListItem(
                                    video,
                                    config: VideoListItemConfig(
                                        hasQueueEntry: true,
                                        videoDuration: video.duration,
                                        isNew: video.isNew,
                                        showAllStatus: false,
                                        clearRole: .destructive,
                                        clearAboveBelowList: .queue,
                                        showContextMenu: enableQueueContextMenu,
                                        showVideoListOrder: showVideoListOrder,
                                        showDelete: false,
                                        )
                                )
                            } else {
                                EmptyEntry(entry)
                            }
                        }
                        .id(NavigationManager.getScrollId(entry.video?.youtubeId, ClearList.queue.rawValue))
                        .videoListItemEntry()
                    }
                    .moveQueueEntryModifier()
                    .handleDynamicVideoURLDrop(.queue)
                    .listRowBackground(Color.backgroundColor)

                    if !queue.isEmpty {
                        ClearAllQueueEntriesButton()
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(queue.isEmpty)
            }
            .myNavigationTitle("queue", showBack: false)
            .sendableSubscriptionDestination()
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                ToolbarSpacerWorkaround()
                RefreshToolbarButton()
            }
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId("top", ClearList.queue.rawValue)
        }
    }
}

#Preview {
    @Previewable @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]

    QueueView(queue: queue)
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
}
