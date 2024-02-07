//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit

struct QueueView: View {
    @AppStorage(Const.shortcutHasBeenUsed) var shortcutHasBeenUsed = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == false })
    var subscriptions: [Subscription]

    @State var value: Double = 1.5
    var inboxTip = InboxHasVideosTip()
    var inboxHasEntries: Bool = false

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                if queue.isEmpty {
                    contentUnavailable

                    if inboxHasEntries {
                        VStack {
                            Spacer()
                            TipView(inboxTip, arrowEdge: .bottom)
                                .fixedSize()
                        }
                    }

                } else {
                    List {
                        ForEach(queue) { entry in
                            ZStack {
                                if let video = entry.video {
                                    VideoListItem(video: video)
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
        .onDisappear {
            if inboxHasEntries {
                inboxTip.invalidate(reason: .actionPerformed)
            }
        }
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("noQueueItems", systemImage: "rectangle.stack.badge.play.fill")
        } description: {
            Text("noQueueItemsDescription")
        } actions: {
            if !shortcutHasBeenUsed, let url = UrlService.shareShortcutUrl {
                Link(destination: url) {
                    Label("setupShareSheetAction", systemImage: "square.and.arrow.up.fill")
                }
                .bold()
                .buttonStyle(.borderedProminent)
            }

            if subscriptions.isEmpty {
                Button {
                    navManager.showBrowserSheet = true
                } label: {
                    Label("addFeeds", systemImage: "plus")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .tint(.teal)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items, at: 0)
            return true
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        let task = VideoService.moveQueueEntry(from: source,
                                               to: destination,
                                               modelContext: modelContext)
        if destination == 0 || source.contains(0) {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    func handleUrlDrop(_ items: [URL], at index: Int) {
        print("handleUrlDrop", items)
        let container = modelContext.container
        let task = VideoService.addForeignUrls(items, in: .queue, at: index, container: container)
        if index == 0 {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }
}

#Preview {
    QueueView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
