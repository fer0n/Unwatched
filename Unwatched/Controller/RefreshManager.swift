//
//  RefreshController.swift
//  Unwatched
//

import Foundation
import SwiftData

@Observable class RefreshManager {
    var container: ModelContainer?
    var isLoading: Bool = false

    func refreshAll() {
        refresh()
        UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier) {
        refresh(subscriptionIds: [subscriptionId])
    }

    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil) {
        if let container = container {
            if isLoading { return }
            isLoading = true
            Task {
                let task = VideoService.loadNewVideosInBg(subscriptionIds: subscriptionIds, container: container)
                try? await task.value
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    func refreshOnStartup() {
        let refreshOnStartup = UserDefaults.standard.object(forKey: Const.refreshOnStartup) as? Bool ?? true
        if !refreshOnStartup {
            return
        }

        let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
        let shouldRefresh = lastAutoRefreshDate == nil ||
            lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds

        if shouldRefresh {
            print("refreshing now")
            self.refreshAll()
        }
    }
}
