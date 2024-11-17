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

    var adjusted = [SendableSubscription]()

    var filter: ((SendableSubscription) -> Bool)?
    var sort: ((SendableSubscription, SendableSubscription) -> Bool)?

    @MainActor
    private func fetchSubscriptions() async {
        let subs = await SubscriptionService.getActiveSubscriptions()
        withAnimation {
            subscriptions = subs
            isLoading = false
        }
    }

    @MainActor
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

    @MainActor
    var countText: String {
        if isLoading {
            return ""
        }
        return "(\(subscriptions.count))"
    }

    @MainActor
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

    @MainActor
    func updateSubscriptions(_ ids: Set<PersistentIdentifier>) {
        print("updateSubscriptions: \(ids.count)")
        let modelContext = DataProvider.newContext()
        for persistentId in ids {
            guard let updatedSub = modelContext.model(for: persistentId) as? Subscription else {
                Logger.log.warning("updateSubscription failed: no model found")
                return
            }

            print("updatedSub", updatedSub)

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
