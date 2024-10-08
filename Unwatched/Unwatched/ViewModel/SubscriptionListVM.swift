//
//  SubscriptionListVM.swift
//  Unwatched
//

import SwiftData
import OSLog
import SwiftUI
import UnwatchedShared

@Observable
class SubscriptionListVM {
    var container: ModelContainer?
    var subscriptions = [SendableSubscription]()
    var isLoading = true

    var adjusted = [SendableSubscription]()

    var filter: ((SendableSubscription) -> Bool)?
    var sort: ((SendableSubscription, SendableSubscription) -> Bool)?

    func fetchSubscriptions() async {
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
}
