//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]

    @State var value: Double = 1.5

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                if queue.isEmpty {
                    ContentUnavailableView("noQueueItems",
                                           systemImage: "rectangle.stack.badge.play.fill",
                                           description: Text("noQueueItemsDescription"))
                        .contentShape(Rectangle())
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items, at: 0)
                            return true
                        }
                } else {
                    List {
                        ForEach(queue) { entry in
                            ZStack {
                                if let video = entry.video {
                                    VideoListItem(
                                        video: video,
                                        videoSwipeActions: [.queueBottom, .queueTop, .clear],
                                        onClear: {
                                            VideoService.deleteQueueEntry(entry, modelContext: modelContext)
                                        }
                                    )
                                }
                            }
                            .id(NavigationManager.getScrollId(entry.video?.youtubeId, "queue"))
                        }
                        .onMove(perform: moveQueueEntry)
                        .dropDestination(for: URL.self) { items, index in
                            print("index", index)
                            handleUrlDrop(items, at: index)
                        }
                    }
                }
            }
            .navigationTitle("queue")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .toolbar {
                RefreshToolbarButton()
            }
        }
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId(queue.first?.video?.youtubeId, "queue")
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        let task = VideoService.moveQueueEntry(from: source,
                                               to: destination,
                                               modelContext: modelContext)
        player.loadTopmostVideoFromQueue(after: task)
    }

    func handleUrlDrop(_ items: [URL], at index: Int) {
        print("handleUrlDrop", items)
        let task = VideoService.addForeignUrls(items, in: .queue, at: index, modelContext: modelContext)
        player.loadTopmostVideoFromQueue(after: task)
    }
}

#Preview {
    QueueView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
