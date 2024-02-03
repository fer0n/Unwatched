//
//  SubscribeManager.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI

@Observable class SubscribeManager {
    var container: ModelContainer?

    var isSubscribedSuccess: Bool?
    var isLoading: Bool

    var errorMessage: String?
    var newSubs: [SubscriptionState]?
    var showDropResults = false

    var hasNewSubscriptions = false

    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }

    func reset() {
        isSubscribedSuccess = nil
        isLoading = false
    }

    func isSubscribed(video: Video?) -> Bool {
        return SubscriptionService.isSubscribed(video)
    }

    func setIsSubscribed(_ channelId: String?) {
        guard let container = container else {
            print("checkIsSubscribed has no ModelContainer")
            return
        }
        isLoading = true
        Task {
            let task = SubscriptionService.isSubscribed(channelId, container: container)
            let isSubscribed = await task.value
            await MainActor.run {
                self.isSubscribedSuccess = isSubscribed
                isLoading = false
            }
        }
    }

    func getSubscriptionSystemName(video: Video?) -> String? {
        guard let video = video else {
            return nil
        }
        if isSubscribedSuccess == true {
            return "checkmark"
        }
        if !SubscriptionService.isSubscribed(video) {
            return "arrow.right.circle"
        }
        return nil
    }

    func getSubscriptionSystemName() -> String {
        if isLoading {
            return "ellipsis"
        }
        if isSubscribedSuccess == true {
            return "checkmark"
        }
        return "plus"
    }

    func unsubscribe(_ channelId: String) {
        guard let container = container else {
            print("addNewSubscription has no container")
            return
        }
        isSubscribedSuccess = nil
        isLoading = true
        Task {
            do {
                let task = SubscriptionService.unsubscribe(channelId, container: container)
                try await task.value
                await MainActor.run {
                    isSubscribedSuccess = false
                }
            } catch {
                print("unsubscribe error: \(error)")
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }

    func addSubscription(_ channelId: String? = nil, subscriptionId: PersistentIdentifier? = nil) {
        guard let container = container else {
            print("addNewSubscription has no container")
            return
        }

        isSubscribedSuccess = nil
        isLoading = true
        Task {
            do {
                try await SubscriptionService.addSubscription(channelId: channelId,
                                                              subsciptionId: subscriptionId,
                                                              modelContainer: container)
                await MainActor.run {
                    isSubscribedSuccess = true
                    hasNewSubscriptions = true
                }
            } catch {
                print("addNewSubscription error: \(error)")
                await MainActor.run {
                    isSubscribedSuccess = false
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
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
                        isSubscribedSuccess = false
                        // alerter.showError(error)
                        // TODO: throw error? Show alert?
                    }
                }
                isLoading = false
            }
        }
    }

    func addSubscriptionFromText(_ text: String) {
        let urls: [URL] = text.components(separatedBy: "\n").compactMap { str in
            if !str.isValidURL || str.isEmpty {
                return nil
            }
            return URL(string: str)
        }
        if urls.isEmpty {
            errorMessage = "No urls found"
        }
        addSubscription(from: urls)
    }

    func addSubscription(from urls: [URL]) {

        //        newSubs = nil
        guard let container = container else {
            print("no container in addSubscriptionFromText")
            return
        }
        errorMessage = nil
        isLoading = true

        Task.detached {
            print("load new")
            do {
                let subs = try await SubscriptionService.addSubscriptions(from: urls, modelContainer: container)
                let hasError = subs.first(where: { !($0.alreadyAdded || $0.success) }) != nil
                await MainActor.run {
                    self.newSubs = subs
                    if hasError {
                        self.showDropResults = true
                    } else {
                        self.isSubscribedSuccess = true
                    }
                }
            } catch {
                print("\(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showDropResults = true
                }
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// get correct icon depending on subscription state (get systemName func)
// handle subscription state (trigger subscribe/unsubscribe)
