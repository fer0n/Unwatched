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
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false
    @AppStorage(Const.showVideoListOrder) var showVideoListOrder: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player

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
                                        videoDuration: video.duration,
                                        isNew: video.isNew,
                                        showPlayingStatus: false,
                                        clearRole: .destructive,
                                        clearAboveBelowList: .queue,
                                        showContextMenu: enableQueueContextMenu,
                                        showVideoListOrder: showVideoListOrder,
                                        showDelete: false,
                                        )
                                )
                                .autoMarkSeen(video)
                            } else {
                                EmptyEntry(entry)
                            }
                        }
                        .id(NavigationManager.getScrollId(entry.video?.youtubeId, ClearList.queue.rawValue))
                        .videoListItemEntry()
                    }
                    .onMove(perform: moveQueueEntry)
                    .handleDynamicVideoURLDrop(.queue)
                    .listRowBackground(Color.backgroundColor)

                    if showClearQueueButton && queue.count >= Const.minListEntriesToShowClear {
                        ClearAllVideosButton(clearAll: clearAll)
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(queue.isEmpty)
            }
            .myNavigationTitle("queue", showBack: false)
            .navigationDestination(for: SendableSubscription.self) { sub in
                SendableSubscriptionDetailView(sub, modelContext)
                    .foregroundStyle(Color.neutralAccentColor)
            }
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

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        if source.count == 1 && source.first == destination {
            return
        }
        VideoService.moveQueueEntry(from: source,
                                    to: destination,
                                    updateIsNew: true,
                                    modelContext: modelContext)
        if destination == 0 || source.contains(0) {
            player.loadTopmostVideoFromQueue()
        }
    }

    func clearAll() {
        VideoService.deleteQueueEntries(queue, modelContext: modelContext)
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
