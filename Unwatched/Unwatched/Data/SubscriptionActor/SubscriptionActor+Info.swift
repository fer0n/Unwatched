//
//  SubscriptionActor+Info.swift
//  Unwatched
//

import SwiftData
import OSLog
import UnwatchedShared

extension SubscriptionActor {

    func verifySubscriptionInfo(
        _ sub: SendableSubscription,
        unarchiveSubIfAvailable: Bool = false
    ) async -> (SubscriptionState, SendableSubscription?) {
        Log.info("verifySubscriptionInfo: \(sub.title)")
        Log.info("youtubePlaylistId: \(sub.youtubePlaylistId?.debugDescription ?? "")")
        var subState = SubscriptionState(title: sub.title)

        if let title = getTitleIfSubscriptionExists(
            channelId: sub.youtubeChannelId,
            unarchiveSubIfAvailable
        ) {
            Log.info("found existing sub via channelId")
            subState.title = title
            subState.alreadyAdded = true
            return (subState, nil)
        }

        do {
            var url: URL
            if let playlistId = sub.youtubePlaylistId {
                url = try UrlService.getPlaylistFeedUrl(playlistId)
            } else if let channelId = sub.youtubeChannelId {
                url = try UrlService.getFeedUrlFromChannelId(channelId)
            } else {
                Log.info("no info for verify")
                subState.error = "no info found"
                return (subState, nil)
            }
            Log.info("url: \(url.absoluteString)")
            let sendableSub = try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: url)
            subState.success = true
            return (subState, sendableSub)
        } catch {
            subState.error = error.localizedDescription
        }

        return (subState, nil)
    }

    func loadSubscriptionInfo(
        from url: URL,
        unarchiveSubIfAvailable: Bool = false
    ) async -> (SubscriptionState, SendableSubscription?) {
        var subState = SubscriptionState(url: url)
        do {
            subState.channelId = UrlService.getChannelIdFromUrl(url)
            subState.userName = UrlService.getChannelUserNameFromUrl(url)
            subState.playlistId = UrlService.getPlaylistIdFromUrl(url)

            if let title = getTitleIfSubscriptionExists(
                channelId: subState.channelId,
                userName: subState.userName,
                playlistId: subState.playlistId,
                unarchiveSubIfAvailable
            ) {
                Log.info("loadSubscriptionInfo: found existing sub via userName")
                subState.title = title
                subState.alreadyAdded = true
                return (subState, nil)
            }

            if let sendableSub = try await SubscriptionActor.getSubscription(url: url,
                                                                             channelId: subState.channelId,
                                                                             userName: subState.userName,
                                                                             playlistId: subState.playlistId) {
                let channelId = sendableSub.youtubeChannelId
                if channelId != nil || sendableSub.youtubePlaylistId != nil,
                   let title = getTitleIfSubscriptionExists(channelId: channelId,
                                                            playlistId: subState.playlistId,
                                                            unarchiveSubIfAvailable) {
                    Log.info("loadSubscriptionInfo: found existing sub via channelId")
                    subState.title = title
                    subState.alreadyAdded = true
                    return (subState, nil)
                }

                subState.title = sendableSub.title
                subState.success = true
                return (subState, sendableSub)
            }
        } catch {
            subState.error = error.localizedDescription
        }
        return (subState, nil)
    }

    func isSubscribed(channelId: String?, playlistId: String?, updateInfo: SubscriptionInfo? = nil) -> Bool {
        Log.info("isSubscribed; channelId: \(channelId ?? ""), playlistId: \(playlistId ?? "")")
        var fetch: FetchDescriptor<Subscription>
        if let playlistId {
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                playlistId == $0.youtubePlaylistId
            })
            let subs = try? modelContext.fetch(fetch)
            if let first = subs?.first {
                updateSubscriptionInfo(first, info: updateInfo)
                return !first.isArchived
            }
        } else if let channelId {
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                channelId == $0.youtubeChannelId
            })
            let subs = try? modelContext.fetch(fetch)
            if let subs {
                for sub in subs {
                    // For playlist subscriptions, only update the image
                    // playlist images are the same as the channel page
                    if sub.youtubePlaylistId != nil {
                        updateSubscriptionImage(sub, imageUrl: updateInfo?.imageUrl)
                    } else {
                        updateSubscriptionInfo(sub, info: updateInfo)
                    }
                }
                return subs.contains { !$0.isArchived && $0.youtubePlaylistId == nil }
            }
        } else {
            Log.error("isSubscribed: Neither channelId nor playlistId given")
            return false
        }
        return false
    }

    private func updateSubscriptionInfo(_ sub: Subscription, info: SubscriptionInfo?) {
        Log.info("updateSubscriptionInfo: \(sub.title), \(info.debugDescription)")
        guard let info else {
            Log.info("no info to update subscription with")
            return
        }
        sub.youtubeUserName = info.userName ?? sub.youtubeUserName
        updateSubscriptionImage(sub, imageUrl: info.imageUrl)

        if sub.title.isEmpty || info.title != sub.title,
           let title = info.title {
            sub.title = title
        }
        try? modelContext.save()
    }

    private func updateSubscriptionImage(_ sub: Subscription, imageUrl: URL?) {
        if let imageUrl,
           sub.thumbnailUrl != imageUrl {
            Log.info("Updating thumbnail url")
            if let oldUrl = sub.thumbnailUrl {
                imageUrlsToBeDeleted.append(oldUrl)
            }
            sub.thumbnailUrl = imageUrl
            try? modelContext.save()
        }
    }

    func getTitleIfSubscriptionExists(channelId: String? = nil,
                                      userName: String? = nil,
                                      playlistId: String? = nil,
                                      _ unarchiveSubIfAvailable: Bool = false) -> String? {
        if channelId == nil && userName == nil && playlistId == nil { return nil }
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            (playlistId == nil || playlistId == $0.youtubePlaylistId) &&
                ((channelId != nil && channelId == $0.youtubeChannelId) ||
                    (userName != nil && $0.youtubeUserName == userName))
        })
        fetch.fetchLimit = 1
        let subs = try? modelContext.fetch(fetch)
        if let sub = subs?.first {
            if unarchiveSubIfAvailable {
                unarchive(sub)
            }
            let title = sub.title
            return title
        }
        return nil
    }
}
