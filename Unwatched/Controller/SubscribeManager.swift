//
//  SubscribeManager.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI
import OSLog

@Observable class SubscribeManager {
    weak var container: ModelContainer?

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

    @MainActor
    func setIsSubscribed(_ subscriptionInfo: SubscriptionInfo?) async {
        guard let container = container else {
            Logger.log.warning("checkIsSubscribed has no ModelContainer")
            return
        }
        isLoading = true
        let task = SubscriptionService.isSubscribed(channelId: subscriptionInfo?.channelId,
                                                    playlistId: subscriptionInfo?.playlistId,
                                                    container: container)
        let isSubscribed = await task.value
        self.isSubscribedSuccess = isSubscribed
        isLoading = false
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

    func unsubscribe(_ info: SubscriptionInfo) async {
        guard let container = container,
              info.channelId != nil && info.playlistId != nil else {
            Logger.log.warning("addNewSubscription has no container/channelId/playlistId")
            return
        }
        isSubscribedSuccess = nil
        isLoading = true
        do {
            let task = SubscriptionService.unsubscribe(info, container: container)
            try await task.value
            isSubscribedSuccess = false
        } catch {
            Logger.log.error("unsubscribe error: \(error)")
        }
        isLoading = false
    }

    func addSubscription(_ subscriptionInfo: SubscriptionInfo? = nil,
                         subscriptionId: PersistentIdentifier? = nil) async {
        guard let container = container else {
            Logger.log.warning("addNewSubscription has no container")
            return
        }

        isSubscribedSuccess = nil
        isLoading = true
        do {
            try await SubscriptionService.addSubscription(subscriptionInfo: subscriptionInfo,
                                                          subsciptionId: subscriptionId,
                                                          modelContainer: container)
            isSubscribedSuccess = true
            hasNewSubscriptions = true
        } catch {
            Logger.log.error("addNewSubscription error: \(error)")
            errorMessage = error.localizedDescription
            isSubscribedSuccess = false
        }
        isLoading = false
    }

    func handleSubscription(_ videoId: PersistentIdentifier) async {
        guard let container = container else {
            return
        }
        let context = ModelContext(container)
        guard let video = context.model(for: videoId) as? Video else {
            Logger.log.info("handleSubscription: video not found")
            return
        }
        isSubscribedSuccess = nil
        isLoading = true

        let isSubscribed = isSubscribed(video: video)
        if isSubscribed {
            guard let subId = video.subscription?.id else {
                Logger.log.info("no subId to un/subscribe")
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
            let subscriptionInfo = SubscriptionInfo(channelId: channelId)
            let subId = video.subscription?.id
            do {
                try await SubscriptionService.addSubscription(
                    subscriptionInfo: subscriptionInfo,
                    subsciptionId: subId,
                    modelContainer: container)
                isSubscribedSuccess = true
            } catch {
                Logger.log.error("error subscribing: \(error)")
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
        try? context.save()
    }

    func addSubscriptionFromText(_ text: String) async {
        let urls: [URL] = text.components(separatedBy: "\n").compactMap { str in
            if !str.isValidURL || str.isEmpty {
                return nil
            }
            return URL(string: str)
        }
        if urls.isEmpty {
            errorMessage = "No urls found"
            return
        }
        let subscriptionInfo = urls.map { SubscriptionInfo(rssFeedUrl: $0) }
        await addSubscription(subscriptionInfo: subscriptionInfo)
    }

    @MainActor
    func addSubscription(subscriptionInfo: [SubscriptionInfo]) async {
        guard let container = container else {
            Logger.log.warning("no container in addSubscriptionFromText")
            return
        }
        errorMessage = nil
        isLoading = true

        Logger.log.info("load new")
        do {
            let subs = try await SubscriptionService.addSubscriptions(
                subscriptionInfo: subscriptionInfo,
                modelContainer: container
            )
            let hasError = subs.first(where: { !($0.alreadyAdded || $0.success) }) != nil
            self.newSubs = subs
            if hasError {
                self.showDropResults = true
            } else {
                self.isSubscribedSuccess = true
            }
        } catch {
            Logger.log.error("\(error)")
            self.errorMessage = error.localizedDescription
            self.showDropResults = true
        }
        self.isLoading = false
    }
}

// get correct icon depending on subscription state (get systemName func)
// handle subscription state (trigger subscribe/unsubscribe)
