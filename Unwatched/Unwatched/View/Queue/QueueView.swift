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

    @Environment(TinyUndoManager.self) private var undoManager
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) private var modelContext

    @Query(QueueView.descriptor, animation: .default)
    var queue: [QueueEntry]

    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                MyBackgroundColor()

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
                                let videoId = video.persistentModelID
                                let youtubeId = video.youtubeId

                                VideoListItem(
                                    video,
                                    video.youtubeId,
                                    config: VideoListItemConfig(
                                        hasQueueEntry: true,
                                        videoDuration: video.duration,
                                        isNew: video.isNew,
                                        showAllStatus: false,
                                        clearRole: .destructive,
                                        queueRole: Const.iOS26 ? .destructive : nil,
                                        clearAboveBelowList: .queue,
                                        showContextMenu: enableQueueContextMenu,
                                        showDelete: false,
                                        ),
                                    onChange: { reason, order in
                                        handleChange(reason, videoId, youtubeId, order ?? entry.order)
                                    }
                                )
                                .equatable()
                                .id(NavigationManager.getScrollId(entry.video?.youtubeId, ClearList.queue.rawValue))
                            } else {
                                EmptyEntry(entry)
                            }
                        }
                        .videoListItemEntry()
                    }
                    .moveQueueEntryModifier()
                    .myListRowBackground()

                    if !queue.isEmpty {
                        ClearAllQueueEntriesButton(
                            willClearAll: willClearAll
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(queue.isEmpty)
            }
            .myNavigationTitle("queue")
            .sendableSubscriptionDestination()
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                ToolbarSpacerWorkaround()
                UndoToolbarButton()
                RefreshToolbarContent()
            }
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId("top", ClearList.queue.rawValue)
        }
        .onDisappear {
            Signal.log(
                "Queue.Count",
                parameters: ["Queue.Count.Value": "\(queue.count)"],
                throttle: .weekly
            )
        }
    }

    static var descriptor: FetchDescriptor<QueueEntry> {
        FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\QueueEntry.order)])
    }

    func willClearAll() {
        let videoIds = queue.compactMap { $0.video?.persistentModelID }
        undoManager.registerAction(.moveToInbox(videoIds))
    }

    func handleChange(
        _ reason: VideoChangeReason?,
        _ videoId: PersistentIdentifier,
        _ youtubeId: String,
        _ order: Int
    ) {
        guard let reason else {
            return
        }
        switch reason {
        case .clearEverywhere, .moveToInbox, .toggleWatched:
            undoManager.registerAction(
                .moveToQueue([videoId], order: order)
            )
        case .clearAbove:
            undoManager.handleQueueClearDirection(youtubeId, queue, order, .above)
        case .clearBelow:
            undoManager.handleQueueClearDirection(youtubeId, queue, order, .below)
        case .moveToQueue:
            break
        }
    }
}

#Preview {
    QueueView()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
        .environment(TinyUndoManager())
}
