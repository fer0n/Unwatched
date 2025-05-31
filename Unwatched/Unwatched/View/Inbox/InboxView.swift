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
                                VideoListItem(
                                    video,
                                    config: VideoListItemConfig(
                                        isNew: video.isNew,
                                        clearRole: .destructive,
                                        queueRole: .destructive,
                                        clearAboveBelowList: .inbox,
                                        showQueueButton: showAddToQueueButton,
                                        showDelete: false,
                                        )
                                )
                                .autoMarkSeen(video)
                            } else {
                                EmptyEntry(entry)
                            }
                        }
                        .id(NavigationManager.getScrollId(entry.video?.youtubeId, ClearList.inbox.rawValue))
                        .videoListItemEntry()
                    }
                    .handleDynamicVideoURLDrop(.inbox)
                    .listRowBackground(Color.backgroundColor)

                    if hasTooManyItems {
                        HiddenEntriesInfo()
                    }

                    ClearAllInboxEntriesButton()
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
        inboxEntries.count >= Const.inboxFetchLimit
    }

    func deleteInboxEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = inboxEntries[index]
            deleteInboxEntry(entry)
        }
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        VideoService.deleteInboxEntry(entry, modelContext: modelContext)
    }
}

#Preview {
    InboxView(inboxEntries: [])
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
