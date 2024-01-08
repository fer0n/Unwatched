//
//  InboxView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \InboxEntry.video.publishedDate, order: .reverse) var inboxEntries: [InboxEntry]

    var loadNewVideos: () async -> Void

    func deleteInboxEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = inboxEntries[index]
            deleteInboxEntry(entry)
        }
    }

    func deleteInboxEntry(_ entry: InboxEntry) {
        QueueManager.deleteInboxEntry(modelContext: modelContext, entry: entry)
    }

    func addVideoToQueue(_ entry: InboxEntry) {
        QueueManager.insertQueueEntries(
            videos: [entry.video],
            modelContext: modelContext)
        deleteInboxEntry(entry)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if inboxEntries.isEmpty {
                    BackgroundPlaceholder(systemName: "tray.fill")
                }

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
        }
        .listStyle(.plain)
    }

}

#Preview {
    InboxView(loadNewVideos: { })
}
