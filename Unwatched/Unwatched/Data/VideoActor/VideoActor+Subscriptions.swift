//
//  VideoActor+Subscriptions.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation
import OSLog
import UnwatchedShared

// Subscriptions
extension VideoActor {

    /// Fetch the existing Subscription via SendableSubscription's persistentId
    func getSubscription(via sub: SendableSubscription) -> Subscription? {
        if let subId = sub.persistentId, let modelSub = self[subId, as: Subscription.self] {
            return modelSub
        }
        Log.info("subscription does not exist: \(sub.title)")
        return nil
    }

    func subscriptionExists(_ channelId: String) throws -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        if let subs = try? modelContext.fetch(fetch) {
            if let sub = subs.first {
                return sub
            }
        }
        return nil
    }

    func getAllActiveSubscriptions() throws -> [Subscription] {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isArchived == false })
        return try modelContext.fetch(fetch)
    }

    func fetchSubscriptions(_ subscriptionIds: [PersistentIdentifier]?) throws -> [Subscription] {
        var subs = [Subscription]()
        if let ids = subscriptionIds {
            for id in ids {
                if let loadedSub = self[id, as: Subscription.self] {
                    subs.append(loadedSub)
                } else {
                    Log.warning("Subscription not found for id: \(id.hashValue)")
                }
            }
        } else {
            let fetchDescriptor = FetchDescriptor<Subscription>()
            subs = try modelContext.fetch(fetchDescriptor)
        }
        return subs
    }

    func addToCorrectSubscription(_ video: Video, channelId: String) {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        let subscriptions = try? modelContext.fetch(fetch)
        if let sub = subscriptions?.first {
            sub.videos?.append(video)
            for video in sub.videos ?? [] {
                video.youtubeChannelId = sub.youtubeChannelId
            }
        }
    }

    func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) async throws {
        Log.info("addSubscriptionsForVideos")
        guard let channelId = video.youtubeChannelId else {
            Log.info("no channel Id/title found in video")
            return
        }

        // video already added, done here
        guard video.subscription == nil else {
            Log.info("video already has a subscription")
            return
        }

        // check if subs exists (in video or in db)
        if let existingSub = try subscriptionExists(channelId) {
            existingSub.videos?.append(video)
            return
        }

        // create subs where missing
        let channelLink = try UrlService.getFeedUrlFromChannelId(channelId)
        let sub = Subscription(
            link: channelLink,
            title: feedTitle ?? "",
            isArchived: true,
            youtubeChannelId: channelId)
        Log.info("new sub: \(sub.isArchived)")

        modelContext.insert(sub)
        sub.videos?.append(video)
    }

    /// Fetches all videos for the specified subscription.
    func fetchVideos(_ sub: SendableSubscription) async throws -> FetchResult {
        guard let url = sub.link else {
            Log.info("sub has no url: \(sub.title)")
            return FetchResult(sub: sub, videos: [], errorMessage: nil)
        }
        do {
            let videos = try await VideoCrawler.loadVideosFromRSS(url: url)
            return FetchResult(sub: sub, videos: videos, errorMessage: nil)
        } catch {
            if Task.isCancelled {
                throw error
            }
            Log.error(
                "Failed to fetch videos for subscription: \(sub.title), error: \(error.localizedDescription)"
            )
            fetchErrors.append(error)
            return FetchResult(sub: sub, videos: [], errorMessage: error.localizedDescription)
        }
    }

    /// Writes the run's per-feed outcomes onto the subscriptions, so a feed that keeps failing can be told apart from
    /// one that failed once.
    func recordFetchOutcomes(_ outcomes: [FetchOutcome]) {
        guard !outcomes.isEmpty else { return }
        let failureShare = Double(outcomes.filter(\.didFail).count) / Double(outcomes.count)
        if outcomes.count > 1 && failureShare >= Const.refreshFailedThreshold {
            Log.info("recordFetchOutcomes: \(failureShare) failed, treating as an outage")
            return
        }

        for outcome in outcomes {
            guard let sub = self[outcome.subscriptionId, as: Subscription.self] else { continue }
            if let errorMessage = outcome.errorMessage {
                sub.failedFetchCount += 1
                sub.lastFetchFailedDate = .now
                sub.lastFetchErrorMessage = errorMessage
            } else if sub.failedFetchCount != 0 || sub.lastFetchErrorMessage != nil {
                sub.failedFetchCount = 0
                sub.lastFetchFailedDate = nil
                sub.lastFetchErrorMessage = nil
            }
        }
    }

    /// Returns specified Subscriptions and returns them as Sendable.
    /// If none are specified, returns all active subscriptions.
    func getSubscriptions(_ subscriptionIds: [PersistentIdentifier]?) throws -> [SendableSubscription] {
        var subs = [Subscription]()
        if subscriptionIds == nil {
            subs = try getAllActiveSubscriptions()
            Log.info("all subs \(subs)")
        } else {
            Log.info("found some, fetching")
            subs = try fetchSubscriptions(subscriptionIds)
        }
        let sendableSubs: [SendableSubscription] = subs.compactMap { $0.toExport }
        return sendableSubs
    }
}
