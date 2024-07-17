//
//  SubscriptionListSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct SubscriptionListSection: View {
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSorting: SubscriptionSorting = .recentlyAdded
    @Query var subscriptions: [Subscription]

    @Binding var subManager: SubscribeManager
    var theme: ThemeColor

    @State var text = DebouncedText(0.1)
    @State var droppedUrls: [URL]?
    @State var isDragOver: Bool = false

    var body: some View {
        MySection("subscriptions") {
            if subscriptions.isEmpty {
                dropArea
                    .listRowInsets(EdgeInsets())
            } else {
                SubscriptionSearchBar(text: $text,
                                      subscriptionSorting: $subscriptionSorting)

                SubscriptionListView(
                    sort: subscriptionSorting,
                    manualFilter: {
                        text.debounced.isEmpty
                            || $0.displayTitle.localizedStandardContains(text.debounced)
                    }
                )
                .dropDestination(for: URL.self) { items, _ in
                    handleUrlDrop(items)
                    return true
                }
            }
        }
        .task(id: droppedUrls) {
            await addDroppedUrls()
        }
        .task(id: text.val) {
            await text.handleDidSet()
        }
    }

    var dropArea: some View {
        ZStack {
            Rectangle()
                .fill(isDragOver ? theme.color.opacity(0.1) : .clear)

            VStack(spacing: 10) {
                Text("dropSubscriptionHelper")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(25)
        }
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items)
            return true
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    func addDroppedUrls() async {
        guard let urls = droppedUrls else {
            return
        }
        Logger.log.info("handleUrlDrop library \(urls)")
        let subscriptionInfo = urls.map { SubscriptionInfo(rssFeedUrl: $0) }
        await subManager.addSubscription(subscriptionInfo: subscriptionInfo)
    }

    func handleUrlDrop(_ urls: [URL]) {
        droppedUrls = urls
    }
}
