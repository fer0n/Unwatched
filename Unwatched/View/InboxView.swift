//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query(sort: \InboxEntry.video.publishedDate, order: .reverse) var inboxEntries: [InboxEntry]
    @State private var showingClearAllAlert = false

    var loadNewVideos: () async -> Void

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
        VideoService.addForeignUrls(items, in: .inbox, modelContext: modelContext)
    }

    func clearAll() {
        VideoService.deleteInboxEntries(inboxEntries, modelContext: modelContext)
    }

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionInbox) {
            ZStack {

                if inboxEntries.isEmpty {
                    BackgroundPlaceholder(systemName: "tray.fill")
                }

                List {
                    ForEach(inboxEntries) { entry in
                        VideoListItem(video: entry.video, videoSwipeActions: [.queue], onAddToQueue: {
                            deleteInboxEntry(entry)
                        })
                    }
                    .onDelete(perform: deleteInboxEntryIndexSet)
                    .dropDestination(for: URL.self) { items, _ in
                        handleUrlDrop(items)
                    }
                }
                .refreshable {
                    await loadNewVideos()
                }

            }
            .navigationBarTitle("Inbox")
            .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .toolbar {
                if !inboxEntries.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingClearAllAlert = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .alert("Confirm Clear All", isPresented: $showingClearAllAlert, actions: {
            Button("Clear All", role: .destructive) {
                clearAll()
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Are you sure you want to clear all items from the inbox?")
        })
    }

}

#Preview {
    InboxView(loadNewVideos: { })
}
