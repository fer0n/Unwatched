//
//  QueueListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct ChangedEntry {
    let videoId: PersistentIdentifier
    let youtubeId: String
    let order: Int
}

struct QueueListView: View {
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false

    @Environment(TinyUndoManager.self) private var undoManager
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) private var modelContext

    @Query var queue: [QueueEntry]

    let filter: QueueFilter
    let title: LocalizedStringKey
    let tag: Tag?
    @Binding var showAll: Bool

    init(
        filter: QueueFilter,
        title: LocalizedStringKey,
        tag: Tag?,
        showAll: Binding<Bool>
    ) {
        self.filter = filter
        self.title = title
        self.tag = tag
        _showAll = showAll
        _queue = Query(
            filter.descriptor(limit: showAll.wrappedValue ? nil : Const.queueFetchLimit),
            animation: .default
        )
    }

    var body: some View {
        @Bindable var navManager = navManager
        let hasTooManyItems = !showAll && queue.count >= Const.queueFetchLimit

        NavigationStack(path: $navManager.presentedQueue) {
            ZStack {
                MyBackgroundColor()

                if queue.isEmpty {
                    QueueViewUnavailable(isFiltered: filter.isActive, tag: tag)
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
                                        queueRole: .destructive,
                                        clearAboveBelowList: .queue,
                                        showContextMenu: enableQueueContextMenu,
                                        showDelete: false,
                                        delayQueueAction: true,
                                        ),
                                    onChange: { reason, order in
                                        handleChange(
                                            reason,
                                            ChangedEntry(
                                                videoId: videoId,
                                                youtubeId: youtubeId,
                                                order: order ?? entry.order
                                            ),
                                            in: queue
                                        )
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

                    if hasTooManyItems {
                        Button {
                            withAnimation {
                                showAll = true
                            }
                        } label: {
                            Text("showAllQueueEntries")
                                .font(.headline)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .listRowSeparator(.hidden)
                        #if !os(visionOS)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.backgroundColor)
                        #endif
                    }

                    if !queue.isEmpty {
                        ClearAllQueueEntriesButton(
                            willClearAll: { willClearAll(queue) }
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(queue.isEmpty)
                .environment(\.videoListContext, .queue)
                .environment(\.queueFilter, filter)
            }
            .myNavigationTitle(title, principal: { QueueTagTitle(title: title) })
            .menuRouteDestination()
            .toolbar {
                #if !os(iOS)
                // the title isn't a view here, so the switcher needs a button of its own
                ToolbarItem(placement: .primaryAction) {
                    QueueTagMenu { symbol in
                        if let symbol {
                            Image(systemName: symbol)
                                .font(.footnote)
                                .fontWeight(.bold)
                        }
                    }
                    .accessibilityLabel("filterByTag")
                }
                #endif
                UndoToolbarButton()
                RefreshToolbarContent()
            }
            .myTint()
        }
        .tint(.neutralAccentColor)
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId("top", ClearList.queue.rawValue)
        }
        .onDisappear {
            Signal.log(
                "Queue.Count",
                parameters: ["Queue.Count.Value": Signal.bucket(queue.count)],
                throttle: .weekly
            )
        }
    }

    func willClearAll(_ entries: [QueueEntry]) {
        let videoIds = entries.compactMap { $0.video?.persistentModelID }
        undoManager.registerAction(.moveToInbox(videoIds))
    }

    /// - Parameter entries: the filtered queue, so undo covers what the action deleted
    func handleChange(_ reason: VideoChangeReason?, _ entry: ChangedEntry, in entries: [QueueEntry]) {
        guard let reason else {
            return
        }
        switch reason {
        case .clearEverywhere, .moveToInbox, .toggleWatched:
            undoManager.registerAction(
                .restoreToQueue(entry.videoId, order: entry.order)
            )
        case .clearAbove:
            undoManager.handleQueueClearDirection(entry.youtubeId, entries, entry.order, .above)
        case .clearBelow:
            undoManager.handleQueueClearDirection(entry.youtubeId, entries, entry.order, .below)
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
