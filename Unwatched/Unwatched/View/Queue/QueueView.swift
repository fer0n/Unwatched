//
//  QueueView.swift
//  Unwatched

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct QueueView: View {
    @State private var showAll = false
    var showCancelButton: Bool = false

    var body: some View {
        QueueListView(
            showAll: $showAll,
            showCancelButton: showCancelButton
        )
    }
}

private struct QueueListView: View {
    @AppStorage(Const.enableQueueContextMenu) var enableQueueContextMenu: Bool = false

    @Environment(TinyUndoManager.self) private var undoManager
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) private var modelContext

    @Query var queue: [QueueEntry]

    @Binding var showAll: Bool
    var showCancelButton: Bool

    init(showAll: Binding<Bool>, showCancelButton: Bool) {
        _showAll = showAll
        self.showCancelButton = showCancelButton

        var descriptor = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\QueueEntry.order)])
        if !showAll.wrappedValue {
            descriptor.fetchLimit = Const.queueFetchLimit
        }
        _queue = Query(descriptor, animation: .default)
    }

    var hasTooManyItems: Bool {
        !showAll && queue.count >= Const.queueFetchLimit
    }

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                MyBackgroundColor()

                if queue.isEmpty {
                    QueueViewUnavailable()
                    #if !os(visionOS)
                    InboxHasEntriesTip()
                    #endif
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
                                // captured while the row renders: undo needs the spot the entry sat
                                // in, which its sparse `order` doesn't give
                                let position = queue.firstIndex(of: entry) ?? 0

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
                                        delayQueueAction: true,
                                        ),
                                    onChange: { reason, order in
                                        handleChange(reason, videoId, youtubeId, order ?? entry.order, position)
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
                parameters: ["Queue.Count.Value": "\(queue.count)"],
                throttle: .weekly
            )
        }
    }

    func willClearAll() {
        let videoIds = queue.compactMap { $0.video?.persistentModelID }
        undoManager.registerAction(.moveToInbox(videoIds))
    }

    /// - Parameter order: the entry's sort key, for picking out the entries above or below it
    /// - Parameter position: where it sat in the queue, for undo to put it back
    func handleChange(
        _ reason: VideoChangeReason?,
        _ videoId: PersistentIdentifier,
        _ youtubeId: String,
        _ order: Int,
        _ position: Int
    ) {
        guard let reason else {
            return
        }
        switch reason {
        case .clearEverywhere, .moveToInbox, .toggleWatched:
            undoManager.registerAction(
                .moveToQueue([videoId], position: position)
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
