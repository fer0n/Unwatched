//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]

    @State var value: Double = 1.5

    var loadNewVideos: () async -> Void

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        VideoService.moveQueueEntry(from: source,
                                    to: destination,
                                    modelContext: modelContext)
    }

    func handleUrlDrop(_ items: [URL], at index: Int) {
        print("handleUrlDrop", items)
        _ = VideoService.addForeignUrls(items, in: .queue, at: index, modelContext: modelContext)
    }

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                if queue.isEmpty {
                    BackgroundPlaceholder(systemName: "rectangle.stack.badge.play.fill")
                }
                List {
                    if queue.isEmpty {
                        ForEach(0..<1) { _ in
                            Color.clear
                                .listRowBackground(Color.clear)
                        }
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items, at: 0)
                        }
                    } else {
                        ForEach(queue) { entry in
                            if let video = entry.video {
                                VideoListItem(
                                    video: video,
                                    videoSwipeActions: [.watched, .queue, .clear],
                                    onTapGuesture: {
                                        navManager.video = entry.video
                                        if entry.order == 0 { return }
                                        VideoService.moveQueueEntry(from: [entry.order],
                                                                    to: 0,
                                                                    modelContext: modelContext)
                                    },
                                    onClear: {
                                        VideoService.deleteQueueEntry(entry, modelContext: modelContext)
                                    }
                                )
                            }
                        }
                        .onMove(perform: moveQueueEntry)
                        .dropDestination(for: URL.self) { items, index in
                            print("index", index)
                            handleUrlDrop(items, at: index)
                        }
                    }
                }
                .navigationBarTitle("Queue")
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
                .refreshable {
                    await loadNewVideos()
                }
            }
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
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
