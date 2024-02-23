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
    var videoToSubscribeTo: Video? {
        didSet {
            Task {
                await handleSubscription()
            }
        }
    }

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
        guard let channelId = channelId else {
            print("no channelId to check subscription status")
            return
        }
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

    func addSubscription(_ channelInfo: ChannelInfo? = nil, subscriptionId: PersistentIdentifier? = nil) {
        guard let container = container else {
            print("addNewSubscription has no container")
            return
        }

        isSubscribedSuccess = nil
        isLoading = true
        Task {
            do {
                try await SubscriptionService.addSubscription(channelInfo: channelInfo,
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

    func handleSubscription() async {
        guard let video = videoToSubscribeTo, let container = container else {
            return
        }

        videoToSubscribeTo = nil
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
            isLoading = false
        } else {
            let channelId = video.subscription?.youtubeChannelId ?? video.youtubeChannelId
            let channelInfo = ChannelInfo(channelId: channelId)
            let subId = video.subscription?.id
            do {
                try await SubscriptionService.addSubscription(
                    channelInfo: channelInfo,
                    subsciptionId: subId,
                    modelContainer: container)
                isSubscribedSuccess = true
            } catch {
                print("error subscribing:", error)
                isSubscribedSuccess = false
            }
            isLoading = false
            do {
                try await Task.sleep(s: 3)
                withAnimation {
                    isSubscribedSuccess = nil
                }
            } catch {}
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
        let channelInfo = urls.map { ChannelInfo(rssFeedUrl: $0) }
        addSubscription(channelInfo: channelInfo)
    }

    func addSubscription(channelInfo: [ChannelInfo]) {
        guard let container = container else {
            print("no container in addSubscriptionFromText")
            return
        }
        errorMessage = nil
        isLoading = true

        Task.detached {
            print("load new")
            do {
                let subs = try await SubscriptionService.addSubscriptions(channelInfo: channelInfo, modelContainer: container)
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
