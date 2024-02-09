//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit

struct InboxView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query(sort: \InboxEntry.date, order: .reverse) var inboxEntries: [InboxEntry]
    @State private var showingClearAllAlert = false

    var swipeTip = InboxSwipeTip()

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            ZStack {
                if inboxEntries.isEmpty {
                    ContentUnavailableView("noInboxItems",
                                           systemImage: "tray.fill",
                                           description: Text("noInboxItemsDescription"))
                        .contentShape(Rectangle())
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                            return true
                        }
                } else {
                    List {
                        swipeTipView
                        ForEach(inboxEntries) { entry in
                            ZStack {
                                if let video = entry.video {
                                    VideoListItem(
                                        video: video,
                                        clearRole: .destructive,
                                        queueRole: .destructive
                                    )
                                }
                            }
                            .id(NavigationManager.getScrollId(entry.video?.youtubeId, "inbox"))
                        }
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                        }
                        if inboxEntries.count > Const.minInboxEntriesToShowClear {
                            clearAllButton
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .onAppear {
                navManager.setScrollId(inboxEntries.first?.video?.youtubeId, "inbox")
            }
            .toolbar {
                RefreshToolbarButton()
            }
            .navigationTitle("inbox")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
        }
        .actionSheet(isPresented: $showingClearAllAlert) {
            ActionSheet(title: Text("confirmClearAll"),
                        message: Text("areYouSureClearAll"),
                        buttons: [
                            .destructive(Text("clearAll")) { clearAll() },
                            .cancel()
                        ])
        }
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

    func deleteInboxEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = inboxEntries[index]
            deleteInboxEntry(entry)
        }
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        VideoService.deleteInboxEntry(entry, modelContext: modelContext)
    }

    func handleUrlDrop(_ items: [URL]) {
        print("handleUrlDrop inbox", items)
        let container = modelContext.container
        _ = VideoService.addForeignUrls(items, in: .inbox, container: container)
    }

    func clearAll() {
        VideoService.deleteInboxEntries(inboxEntries, modelContext: modelContext)
    }

    var clearAllButton: some View {
        Button {
            showingClearAllAlert = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: Const.clearSF)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.teal)
                Spacer()
            }.padding()
        }
    }

}

#Preview {
    InboxView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
