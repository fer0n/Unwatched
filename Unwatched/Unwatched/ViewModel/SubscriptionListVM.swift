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
    var subscriptions = [SendableSubscription]()
    var isLoading = true

    var adjusted = [SendableSubscription]()

    var filter: ((SendableSubscription) -> Bool)?
    var sort: ((SendableSubscription, SendableSubscription) -> Bool)?

    private func fetchSubscriptions() async {
        guard let container = container else {
            isLoading = false
            Logger.log.info("No container found when trying to fetch subscriptions")
            return
        }
        let subs = await SubscriptionService.getActiveSubscriptions(container)
        withAnimation {
            subscriptions = subs
            isLoading = false
        }
    }

    var processedSubs: [SendableSubscription] {
        var subs = subscriptions
        if let filter = filter {
            subs = subs.filter(filter)
        }
        if let sort = sort {
            subs.sort(by: sort)
        }
        return subs
    }

    func setSorting(_ sorting: SubscriptionSorting? = nil) {
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
            self.sort = { $0.displayTitle < $1.displayTitle }
        case .recentlyAdded:
            self.sort = {
                (
                    $0.subscribedDate ?? Date.distantPast
                ) > (
                    $1.subscribedDate ?? Date.distantPast
                )
            }
        case .mostRecentVideo:
            self.sort = {
                (
                    $0.mostRecentVideoDate ?? Date.distantPast
                ) > (
                    $1.mostRecentVideoDate ?? Date.distantPast
                )
            }
        }
    }

    var countText: String {
        if isLoading {
            return ""
        }
        return "(\(subscriptions.count))"
    }

    func updateData() async {
        var loaded = false
        if subscriptions.isEmpty {
            await fetchSubscriptions()
            loaded = true
        }
        let ids = modelsHaveChangesUpdateToken()
        if loaded {
            return
        }
        if let ids = ids {
            updateSubscriptions(ids)
        } else {
            await fetchSubscriptions()
        }
    }

    func updateSubscriptions(_ ids: Set<PersistentIdentifier>) {
        print("updateSubscriptions: \(ids.count)")
        guard let container = container else {
            Logger.log.warning("updateSubscription failed")
            return
        }
        let modelContext = ModelContext(container)
        for persistentId in ids {
            guard let updatedSub = modelContext.model(for: persistentId) as? Subscription else {
                Logger.log.warning("updateSubscription failed: no model found")
                return
            }

            print("updatedSub", updatedSub)

            if let index = subscriptions.firstIndex(where: { $0.persistentId == persistentId }),
               let sendable = updatedSub.toExport {
                subscriptions[index] = sendable
            }
        }
    }
}
