//
//  SubscribeSuggestion.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// Offers to subscribe when a video ends, for people without any subscription
@MainActor
enum SubscribeSuggestion {
    private static let maxShown = 3
    private static let shownCountKey = "subscribeSuggestion.shownCount"

    static func handleVideoEnded(_ video: Video?, _ appNotificationVM: AppNotificationVM) {
        #if os(iOS)
        guard UIApplication.shared.applicationState == .active else { return }
        #endif
        guard let video,
              video.mediaUrl == nil,
              video.isYtShort != true,
              let sub = video.subscription,
              sub.isArchived,
              sub.youtubePlaylistId == nil,
              UserDefaults.standard.integer(forKey: shownCountKey) < maxShown,
              !hasAnySubscription(),
              UserDefaults.standard.shouldPerform(shownCountKey, interval: .daily) else {
            return
        }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: shownCountKey) + 1, forKey: shownCountKey)
        Signal.log("Subscribe.Suggestion")

        appNotificationVM.show(AppNotificationData(
            title: "subscribeSuggestion \(sub.displayTitle)",
            icon: "person.crop.circle.badge.plus",
            timeout: 6,
            action: AppNotificationAction(label: "subscribe") {
                Task {
                    await SubscriptionService.subscribe(sub, source: "suggestion")
                }
            }
        ))
    }

    private static func hasAnySubscription() -> Bool {
        var descriptor = FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isArchived })
        descriptor.fetchLimit = 1
        return ((try? DataProvider.mainContext.fetchCount(descriptor)) ?? 0) > 0
    }
}
