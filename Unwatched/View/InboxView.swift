//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \InboxEntry.video.publishedDate, order: .reverse) var inboxEntries: [InboxEntry]
    @Query var queue: [QueueEntry]

    var loadNewVideos: () async -> Void

    func deleteInboxEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = inboxEntries[index]
            deleteInboxEntry(entry)
        }
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        modelContext.delete(entry)
    }

    func addVideoToQueue(_ entry: InboxEntry) {
        QueueManager.insertQueueEntries(
            videos: [entry.video],
            queue: queue,
            modelContext: modelContext)
        deleteInboxEntry(entry)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(inboxEntries) { entry in
                    VideoListItem(video: entry.video)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                addVideoToQueue(entry)
                            } label: {
                                Image(systemName: "text.badge.plus")
                            }
                            .tint(.teal)
                        }
                }
                .onDelete(perform: deleteInboxEntryIndexSet)
            }
            .refreshable {
                await loadNewVideos()
            }
            .navigationBarTitle("Inbox")
            .toolbarBackground(Color.backgroundColor, for: .navigationBar)
        }
        .listStyle(.plain)
    }

}

#Preview {
    InboxView(loadNewVideos: { })
}
