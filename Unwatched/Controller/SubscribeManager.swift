//
//  SubscribeManager.swift
//  Unwatched
//

import Foundation
import SwiftData

@Observable class SubscribeManager {
    var isSubscribedSuccess: Bool?
    var isLoading = false

    func isSubscribed(video: Video?) -> Bool {
        return SubscriptionService.isSubscribed(video)
    }

    func getSubscriptionSystemName(video: Video?) -> String? {
        guard let video = video else {
            return nil
        }
        if isLoading {
            return "circle.circle"
        }
        if isSubscribedSuccess == true {
            return "checkmark"
        }
        if !SubscriptionService.isSubscribed(video) {
            return "arrow.right.circle"
        }
        return nil
    }

    func handleSubscription(video: Video?, container: ModelContainer) {
        guard let video = video else {
            return
        }

        isSubscribedSuccess = nil
        isLoading = true

        let isSubscribed = isSubscribed(video: video)

        if isSubscribed {
            guard let subId = video.subscription?.id else {
                print("no subId to un/subscribe")
                isLoading = false
                return
            }
            SubscriptionService.deleteSubscriptions(
                [subId],
                container: container)
            isLoading = false
        } else {
            let channelId = video.subscription?.youtubeChannelId ?? video.youtubeChannelId
            let subId = video.subscription?.id
            Task {
                do {
                    try await SubscriptionService.addSubscription(
                        channelId: channelId,
                        subsciptionId: subId,
                        modelContainer: container)
                    await MainActor.run {
                        isSubscribedSuccess = true
                    }
                } catch {
                    await MainActor.run {
                        //                        alerter.showError(error)
                        // TODO: throw error? Show alert?
                    }
                }
                isLoading = false
            }
        }
    }
}

// get correct icon depending on subscription state (get systemName func)
// handle subscription state (trigger subscribe/unsubscribe)
