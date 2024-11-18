//
//  SubscriptionListSection.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct SubscriptionListSection: View {
    @State var subscriptionsVM = SubscriptionListVM()
    @Binding var subManager: SubscribeManager
    var theme: ThemeColor

    @State var droppedUrls: [URL]?
    @State var isDragOver: Bool = false
    @State var text = DebouncedText(0.3)

    var body: some View {
        MySection("subscriptions") {
            if !subscriptionsVM.isLoading {
                if subscriptionsVM.subscriptions.isEmpty {
                    dropArea
                        .listRowInsets(EdgeInsets())
                } else {
                    SearchableSubscriptions(subscriptionsVM: subscriptionsVM, text: $text)
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                            return true
                        }
                }
            } else {
                workaroundPlaceholder
            }
        }
        .task(id: droppedUrls) {
            await addDroppedUrls()
        }
        .task {
            subscriptionsVM.setSorting()
            await subscriptionsVM.updateData()
        }

        Section {
            Text(subscriptionsVM.countText)
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(0)

            Spacer()
                .frame(height: text.debounced.isEmpty ? 0 : 300)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.backgroundColor)
    }

    @ViewBuilder var workaroundPlaceholder: some View {
        // workaround: transparent tabbar in library tab otherwise due to async loading
        if subscriptionsVM.subscriptions.isEmpty && subscriptionsVM.isLoading {
            Spacer()
                .frame(height: UIScreen.main.bounds.size.height)
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

struct SearchableSubscriptions: View {
    var subscriptionsVM: SubscriptionListVM
    @Environment(RefreshManager.self) var refresher

    @AppStorage(Const.subscriptionSortOrder) var subscriptionSorting: SubscriptionSorting = .recentlyAdded

    @Binding var text: DebouncedText

    var body: some View {
        SubscriptionSearchBar(text: $text,
                              subscriptionSorting: $subscriptionSorting)

        SubscriptionListView(subscriptionsVM, onDelete: onDelete)
            .onChange(of: text.debounced) {
                Task {
                    await subscriptionsVM.setSearchText(text.debounced)
                }
            }
            .onChange(of: subscriptionSorting) {
                subscriptionsVM.setSorting(subscriptionSorting, refresh: true)
            }
    }

    var filter: (SendableSubscription) -> Bool {
        {
            text.debounced.isEmpty
                || $0.displayTitle.localizedStandardContains(text.debounced)
        }
    }

    @MainActor
    func onDelete(after task: Task<(), Error>) {
        Task {
            try? await task.value
            await subscriptionsVM.updateData()
        }
    }
}

#Preview {
    SubscriptionListSection(subManager: .constant(SubscribeManager()), theme: .blackWhite)
}
