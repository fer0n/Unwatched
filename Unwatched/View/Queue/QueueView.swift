//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import OSLog

struct QueueView: View {
    @AppStorage(Const.shortcutHasBeenUsed) var shortcutHasBeenUsed = false
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @AppStorage(Const.hasNewQueueItems) var hasNewQueueItems = false

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == false })
    var subscriptions: [Subscription]

    @State var showImportSheet = false
    @State var value: Double = 1.5
    var inboxTip = InboxHasVideosTip()
    var inboxHasEntries: Bool = false
    var showCancelButton: Bool = false

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
                                    VideoListItem(video: video,
                                                  videoDuration: video.duration,
                                                  clearRole: .destructive,
                                                  onChange: handleVideoChange)
                                }
                            }
                            .id(NavigationManager.getScrollId(entry.video?.youtubeId, "queue"))
                        }
                        .onMove(perform: moveQueueEntry)
                        .dropDestination(for: URL.self) { items, index in
                            Logger.log.info("drop at index \(index)")
                            handleUrlDrop(items, at: index)
                        }
                    }
                }
            }
            .navigationTitle("queue")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
                    .foregroundStyle(Color.neutralAccentColor)
            }
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                RefreshToolbarButton()
            }
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
        .sheet(isPresented: $showImportSheet) {
            NavigationStack {
                ImportSubscriptionsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showImportSheet = false
                            } label: {
                                Image(systemName: Const.clearSF)
                            }
                            .tint(.neutralAccentColor)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId(queue.first?.video?.youtubeId, "queue")
        }
        .onDisappear {
            hasNewQueueItems = false
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
                    Image(systemName: "square.and.arrow.up.on.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("setupShareSheetAction")
                }
                .bold()
                .buttonStyle(.borderedProminent)
            }

            if subscriptions.isEmpty {
                Menu {
                    Button {
                        showImportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.down.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text("importSubscriptions")
                    }
                    Button {
                        navManager.openBrowserUrl = .youtubeStartPage
                    } label: {
                        Label("browseFeeds", systemImage: Const.appBrowserSF)
                    }
                } label: {
                    Label("addFeeds", systemImage: "plus")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items, at: 0)
            return true
        }
    }

    func handleVideoChange() {
        if hasNewQueueItems {
            withAnimation {
                hasNewQueueItems = false
            }
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        let task = VideoService.moveQueueEntry(from: source,
                                               to: destination,
                                               modelContext: modelContext)
        if destination == 0 || source.contains(0) {
            player.loadTopmostVideoFromQueue(after: task)
        }
        handleVideoChange()
    }

    func handleUrlDrop(_ items: [URL], at index: Int) {
        Logger.log.info("handleUrlDrop \(items)")
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
