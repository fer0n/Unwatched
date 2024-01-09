//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @State var value: Double = 1.5
    @Environment(\.modelContext) var modelContext

    var loadNewVideos: () async -> Void
    @Query var subscriptions: [Subscription]
    @Query(sort: \QueueEntry.order) var queue: [QueueEntry]

    func deleteQueueEntryIndexSet(_ indexSet: IndexSet) {
        for index in indexSet {
            let entry = queue[index]
            QueueManager.deleteQueueEntry(entry, modelContext: modelContext)
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        QueueManager.moveQueueEntry(from: source,
                                    to: destination,
                                    queue: queue)
    }

    var body: some View {
        NavigationView {
            ZStack {
                if queue.isEmpty {
                    BackgroundPlaceholder(systemName: "rectangle.stack.badge.play.fill")
                }

                List {
                    ForEach(queue) { entry in
                        VideoListItem(video: entry.video)
                            .swipeActions(edge: .leading) {
                                Button {
                                    VideoManager.markVideoWatched(entry.video,
                                                                  modelContext: modelContext)
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
