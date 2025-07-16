//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct InboxView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.showAddToQueueButton) var showAddToQueueButton: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(TinyUndoManager.self) private var undoManager

    @Query(InboxView.descriptor, animation: .default)
    var inboxEntries: [InboxEntry]

    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                if !hasEntries {
                    ContentUnavailableView("noInboxItems",
                                           systemImage: "tray.fill",
                                           description: Text("noInboxItemsDescription"))
                        .contentShape(Rectangle())
                        .handleVideoUrlDrop(.inbox)
                }
                // Workaround: always have the list visible, this avoids a crash when adding the last
                // inbox item to the queue and then moving the video on top of the queue
                List {
                    HideShortsTipView()
                        .id(NavigationManager.getScrollId("top", ClearList.inbox.rawValue))
                        .listRowSeparator(.hidden)

                    if hasTooManyItems {
                        InboxOverflowTipView()
                    }

                    if hasEntries {
                        InboxSwipeTipView()
                            .listRowBackground(Color.backgroundColor)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(inboxEntries) { entry in
                        ZStack {
                            if let video = entry.video {
                                let videoId = video.persistentModelID
                                let youtubeId = video.youtubeId
                                let date = video.publishedDate

                                VideoListItem(
                                    video,
                                    video.youtubeId,
                                    config: VideoListItemConfig(
                                        hasInboxEntry: true,
                                        isNew: video.isNew,
                                        showAllStatus: false,
                                        clearRole: .destructive,
                                        queueRole: .destructive,
                                        clearAboveBelowList: .inbox,
                                        showQueueButton: showAddToQueueButton,
                                        showDelete: false
                                    ),
                                    onChange: { reason in
                                        handleChange(reason, videoId, youtubeId, date)
                                    }
                                )
                                .equatable()
                                .id(NavigationManager.getScrollId(video.youtubeId, ClearList.inbox.rawValue))
                            } else {
                                EmptyEntry(entry)
                            }
                        }
                        .videoListItemEntry()
                    }
                    .listRowBackground(Color.backgroundColor)

                    if hasTooManyItems {
                        HiddenEntriesInfo()
                    }

                    ClearAllInboxEntriesButton(willClearAll: willClearAll)
                        .disabled(!hasEntries)
                        .opacity(hasEntries ? 1 : 0)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
            .onAppear {
                navManager.setScrollId("top", ClearList.inbox.rawValue)
            }
            .inboxToolbar(showCancelButton)
            .myNavigationTitle("inbox", showBack: false)
            .sendableSubscriptionDestination()
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
    }

    var hasEntries: Bool {
        !inboxEntries.isEmpty
    }

    var hasTooManyItems: Bool {
        inboxEntries.count >= (Const.inboxFetchLimit - 1)
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        VideoService.deleteInboxEntry(entry, modelContext: modelContext)
    }

    func willClearAll() {
        let videoIds = inboxEntries.compactMap { $0.video?.persistentModelID }
        undoManager.handleAction(.clear, videoIds)
    }

    func handleChange(_ reason: ChangeReason?, _ videoId: PersistentIdentifier, _ youtubeId: String, _ date: Date?) {
        guard let reason else {
            return
        }
        switch reason {
        case .queue, .clear:
            undoManager.handleAction(reason, [videoId])
        case .clearAbove:
            undoManager.handleClearDirection(youtubeId, date, inboxEntries, .above)
        case .clearBelow:
            undoManager.handleClearDirection(youtubeId, date, inboxEntries, .below)
        default:
            Log.warning("handleChange: Unsupported reason \(reason) for video \(youtubeId)")
        }
    }

    static var descriptor: FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>(
            sortBy: [SortDescriptor(\InboxEntry.date, order: .reverse)]
        )
        descriptor.fetchLimit = Const.inboxFetchLimit
        return descriptor
    }
}

#Preview {
    InboxView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
