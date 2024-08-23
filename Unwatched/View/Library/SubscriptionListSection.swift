//
//  SubscriptionListSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct SubscriptionListSection: View {
    @Query var subscriptions: [Subscription]

    @Binding var subManager: SubscribeManager
    var theme: ThemeColor

    @State var droppedUrls: [URL]?
    @State var isDragOver: Bool = false
    @State var text = DebouncedText(0.3)

    var body: some View {
        MySection("subscriptions") {
            if subscriptions.isEmpty {
                dropArea
                    .listRowInsets(EdgeInsets())
            } else {
                SearchableSubscriptions(text: $text)
                    .dropDestination(for: URL.self) { items, _ in
                        handleUrlDrop(items)
                        return true
                    }
            }
        }
        .task(id: droppedUrls) {
            await addDroppedUrls()
        }

        Section {
            Spacer()
                .frame(height: text.debounced.isEmpty ? 0 : 300)
        }
        .listRowBackground(Color.backgroundColor)
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

struct SearchableSubscriptions: View {
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSorting: SubscriptionSorting = .recentlyAdded
    @Binding var text: DebouncedText

    var body: some View {
        SubscriptionSearchBar(text: $text,
                              subscriptionSorting: $subscriptionSorting)

        SubscriptionListView(
            sort: subscriptionSorting,
            manualFilter: {
                text.debounced.isEmpty
                    || $0.displayTitle.localizedStandardContains(text.debounced)
            }
        )
    }
}

#Preview {
    SubscriptionListSection(subManager: .constant(SubscribeManager()), theme: .blackWhite)
}
