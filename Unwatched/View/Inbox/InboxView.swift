//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import OSLog

struct InboxView: View {
    @AppStorage(Const.hasNewInboxItems) var hasNewInboxItems = false
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query(sort: \InboxEntry.date, order: .reverse) var inboxEntries: [InboxEntry]

    var showCancelButton: Bool = false
    var swipeTip = InboxSwipeTip()

    var body: some View {
        @Bindable var navManager = navManager
        let showClear = inboxEntries.count >= Const.minListEntriesToShowClear

        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            ZStack {
                if inboxEntries.isEmpty {
                    ContentUnavailableView("noInboxItems",
                                           systemImage: "tray.fill",
                                           description: Text("noInboxItemsDescription"))
                        .contentShape(Rectangle())
                        .handleVideoUrlDrop(.inbox)
                } else {
                    List {
                        swipeTipView
                        ForEach(inboxEntries) { entry in
                            ZStack {
                                if let video = entry.video {
                                    VideoListItem(
                                        video,
                                        config: VideoListItemConfig(
                                            clearRole: .destructive,
                                            queueRole: .destructive,
                                            onChange: handleVideoChange,
                                            clearAboveBelowList: .inbox
                                        )
                                    )
                                }
                            }
                            .id(NavigationManager.getScrollId(entry.video?.youtubeId, "inbox"))
                        }
                        .handleVideoUrlDrop(.inbox)
                        ClearAllVideosButton(clearAll: clearAll)
                            .listRowSeparator(.hidden)
                            .opacity(showClear ? 1 : 0)
                            .disabled(!showClear)
                    }
                    .listStyle(.plain)
                }
            }
            .onAppear {
                navManager.setScrollId(inboxEntries.first?.video?.youtubeId, "inbox")
            }
            .onDisappear {
                hasNewInboxItems = false
            }
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                RefreshToolbarButton()
            }
            .navigationTitle("inbox")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
    }

    var swipeTipView: some View {
        TipView(swipeTip)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(action: invalidateTip) {
                    Image(systemName: "text.insert")
                }
                .tint(.teal)

                Button(action: invalidateTip) {
                    Image(systemName: "text.append")
                }
                .tint(.mint)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: invalidateTip) {
                    Image(systemName: Const.clearSF)
                }
                .tint(.black)
            }
    }

    func invalidateTip() {
        swipeTip.invalidate(reason: .actionPerformed)
    }

    func handleVideoChange() {
        if hasNewInboxItems {
            withAnimation {
                hasNewInboxItems = false
            }
        }
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

    func clearAll() {
        VideoService.deleteInboxEntries(inboxEntries, modelContext: modelContext)
        handleVideoChange()
    }
}

#Preview {
    InboxView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
