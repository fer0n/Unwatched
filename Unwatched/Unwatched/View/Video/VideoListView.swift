//
//  VideoListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct VideoListView: View {
    @Query var videos: [Video]

    init(subscriptionId: PersistentIdentifier? = nil,
         sort: VideoSorting? = nil,
         searchText: String = "") {
        let filter = VideoListView.getVideoFilter(subscriptionId, searchText: searchText)
        let sorting = [SortDescriptor<Video>(\.publishedDate, order: .reverse)]
        _videos = Query(filter: filter, sort: sorting, animation: .default)
    }

    var body: some View {
        ForEach(videos) { video in
            VideoListItem(
                video,
                video.youtubeId,
                config: VideoListItemConfig(
                    hasInboxEntry: video.inboxEntry != nil,
                    hasQueueEntry: video.queueEntry != nil,
                    watched: video.watchedDate != nil,
                    deferred: video.deferDate != nil,
                    isNew: video.isNew,
                    )
            )
            .equatable()
            .videoListItemEntry()
        }
        .myListRowBackground()
    }

    nonisolated static func getVideoFilter(_ subscriptionId: PersistentIdentifier? = nil,
                                           searchText: String = "") -> Predicate<Video>? {
        var filter: Predicate<Video>?
        let allSubscriptions = subscriptionId == nil

        let shortsSettingRaw = Int(NSUbiquitousKeyValueStore.default.longLong(forKey: Const.defaultShortsSetting))
        let show = ShortsSetting.show.rawValue
        let defaultSetting = ShortsSetting.defaultSetting.rawValue

        if allSubscriptions {
            filter = #Predicate<Video> { video in
                (!(video.isYtShort ?? false) ||
                    (video.subscription?._shortsSetting == defaultSetting
                        ? shortsSettingRaw
                        : video.subscription?._shortsSetting) == show)
                    && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
            }
        } else {
            filter = #Predicate<Video> { video in
                video.subscription?.persistentModelID == subscriptionId
                    && (!(video.isYtShort ?? false) ||
                            (video.subscription?._shortsSetting == defaultSetting
                                ? shortsSettingRaw
                                : video.subscription?._shortsSetting) == show)
                    && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
            }
        }

        return filter
    }

    /// `flatMap`, not optional chaining: only that shape translates to a plain `IN`. The three
    /// shapes are written out because folding them into one times out the type-checker.
    ///
    /// - Parameters:
    ///   - subscriptionIds: the channels to keep, or — when `isExcluding` — the ones to drop.
    ///   - addedVideoIds: named videos, from any channel. They skip the shorts check.
    ///   - removedVideoIds: named videos to drop, out of the channels otherwise kept.
    nonisolated static func getVideoFilter(
        subscriptionIds: [PersistentIdentifier],
        addedVideoIds: [String] = [],
        removedVideoIds: [String] = [],
        isExcluding: Bool = false
    ) -> Predicate<Video>? {
        let shortsSettingRaw = Int(NSUbiquitousKeyValueStore.default.longLong(forKey: Const.defaultShortsSetting))
        let show = ShortsSetting.show.rawValue
        let defaultSetting = ShortsSetting.defaultSetting.rawValue

        // a video with no channel stays in, the same way the queue reads these modes
        if isExcluding {
            return #Predicate<Video> { video in
                !removedVideoIds.contains(video.youtubeId)
                    && (video.subscription.flatMap { sub in
                        !subscriptionIds.contains(sub.persistentModelID)
                            && (!(video.isYtShort ?? false)
                                    || (sub._shortsSetting == defaultSetting
                                            ? shortsSettingRaw
                                            : sub._shortsSetting) == show)
                    } ?? true)
            }
        }

        if !addedVideoIds.isEmpty {
            return #Predicate<Video> { video in
                addedVideoIds.contains(video.youtubeId)
                    || (video.subscription.flatMap { sub in
                        subscriptionIds.contains(sub.persistentModelID)
                            && (!(video.isYtShort ?? false)
                                    || (sub._shortsSetting == defaultSetting
                                            ? shortsSettingRaw
                                            : sub._shortsSetting) == show)
                    }) == true
            }
        }

        return #Predicate<Video> { video in
            (video.subscription.flatMap { sub in
                subscriptionIds.contains(sub.persistentModelID)
                    && (!(video.isYtShort ?? false)
                            || (sub._shortsSetting == defaultSetting
                                    ? shortsSettingRaw
                                    : sub._shortsSetting) == show)
            }) == true
        }
    }
}
