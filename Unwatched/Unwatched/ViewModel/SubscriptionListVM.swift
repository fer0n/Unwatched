//
//  SubscriptionListVM.swift
//  Unwatched
//

import SwiftData
import OSLog
import SwiftUI
import UnwatchedShared

@Observable
class SubscriptionListVM: TransactionVM<Subscription> {
    @MainActor
    var subscriptions = [SendableSubscription]()

    @MainActor
    var isLoading = true

    @ObservationIgnored var searchText: String?
    private var sort = [SortDescriptor<Subscription>]()

    @MainActor
    private func fetchSubscriptions() async {
        let subs = await SubscriptionService.getActiveSubscriptions(searchText, sort)
        withAnimation {
            subscriptions = subs
            isLoading = false
        }
    }

    @MainActor
    func setSorting(_ sorting: SubscriptionSorting? = nil, refresh: Bool = false) {
        let sorting = {
            if let sorting = sorting {
                return sorting
            } else {
                let sortRaw = UserDefaults.standard.integer(forKey: Const.subscriptionSortOrder)
                return SubscriptionSorting(rawValue: sortRaw) ?? .recentlyAdded
            }
        }()
        switch sorting {
        case .title:
            self.sort = [SortDescriptor<Subscription>(\.title)]
        case .recentlyAdded:
            self.sort = [SortDescriptor<Subscription>(\.subscribedDate, order: .reverse)]
        case .mostRecentVideo:
            self.sort = [SortDescriptor<Subscription>(\.mostRecentVideoDate, order: .reverse)]
        }
        if refresh {
            Task {
                await updateData(force: true)
            }
        }
    }

    @MainActor
    func setSearchText(_ searchText: String) async {
        self.searchText = searchText
        await updateData(force: true)
    }

    @MainActor
    var countText: String {
        if isLoading {
            return ""
        }
        return "(\(subscriptions.count))"
    }

    @MainActor
    func updateData(force: Bool = false) async {
        var loaded = false
        if subscriptions.isEmpty || force {
            await fetchSubscriptions()
            loaded = true
        }
        let ids = await modelsHaveChangesUpdateToken()
        if loaded {
            return
        }
        if let ids = ids {
            updateSubscriptions(ids)
        } else {
            await fetchSubscriptions()
        }
    }

    @MainActor
    func updateSubscriptions(_ ids: Set<PersistentIdentifier>) {
        let modelContext = DataProvider.newContext()
        for persistentId in ids {
            guard let updatedSub = modelContext.model(for: persistentId) as? Subscription else {
                Logger.log.warning("updateSubscription failed: no model found")
                return
            }

            if let index = subscriptions.firstIndex(where: { $0.persistentId == persistentId }) {
                withAnimation {
                    if updatedSub.isArchived {
                        subscriptions.remove(at: index)
                    } else if let sendable = updatedSub.toExport {
                        subscriptions[index] = sendable
                    }
                }
            } else {
                isLoading = true
                Task {
                    await fetchSubscriptions()
                }
                return
            }
        }
    }
}
