//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(\.modelContext) var modelContext

    var onVideoTap: (_ video: Video) -> Void
    var loadNewVideos: () async -> Void
    @Query var subscriptions: [Subscription]
    @Query(sort: \QueueEntry.order) var queue: [QueueEntry]

    func deleteQueueEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = queue[index]
            QueueManager.deleteQueueEntry(entry, queue: queue, modelContext: modelContext)
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        QueueManager.moveQueueEntry(from: source,
                                    to: destination,
                                    queue: queue)
    }

    var body: some View {
        NavigationView {

            List {
                ForEach(queue) { entry in
                    VStack {
                        VideoListItem(video: entry.video)
                            .onTapGesture {
                                onVideoTap(entry.video)
                            }
                        //                    Text("\(entry.order)")
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            VideoManager.markVideoWatched(queueEntry: entry, queue: queue, modelContext: modelContext)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .tint(.teal)
                    }
                }
                .onDelete(perform: deleteQueueEntryIndexSet)
                .onMove(perform: moveQueueEntry)
            }
            .navigationBarTitle("Queue")
            .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            .refreshable {
                await loadNewVideos()
            }
        }
        .listStyle(.plain)
    }
}

// #Preview {
//    do {
//        let schema = Schema([
//            Video.self,
//            Subscription.self,
//            QueueEntry.self,
//            WatchEntry.self
//        ])
//        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//        let container = try ModelContainer(for: QueueEntry.self, configurations: config)
//
//        let video = Video.dummy
//        let queueEntry = QueueEntry(video: video, order: 0)
//        container.mainContext.insert(Video.dummy)
//        container.mainContext.insert(queueEntry)
//
//        return QueueView(onVideoTap: { _ in }, loadNewVideos: { })
//            .modelContainer(container)
//    } catch {
//        fatalError("Failed to create model container.")
//    }
// }
