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
}
