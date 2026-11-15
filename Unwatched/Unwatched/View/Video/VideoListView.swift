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
        _videos = Self.query(subscriptionId: subscriptionId, searchText: searchText)
    }

    static func query(
        subscriptionId: PersistentIdentifier? = nil,
        searchText: String = "",
        limit: Int? = nil
    ) -> Query<Video, [Video]> {
        var fetch = FetchDescriptor<Video>(
            predicate: getVideoFilter(subscriptionId, searchText: searchText),
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
        fetch.fetchLimit = limit
        return Query(fetch, animation: .default)
    }

    var body: some View {
        ForEach(videos) { video in
            VideoListItem(video, video.youtubeId, config: VideoListItemConfig(video))
                .equatable()
                .videoListItemEntry()
        }
        .myListRowBackground()
    }

    nonisolated static func getVideoFilter(_ subscriptionId: PersistentIdentifier? = nil,
                                           searchText: String = "") -> Predicate<Video>? {
        var filter: Predicate<Video>?
        let allSubscriptions = subscriptionId == nil

        let shortsSettingRaw = Int(CloudKeyValueStore.shared.longLong(forKey: Const.defaultShortsSetting))
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

    /// `flatMap`, not optional chaining: only that shape translates to a plain `IN`. The shapes are
    /// written out because folding them into one times out the type-checker.
    ///
    /// - Parameters:
    ///   - subscriptionIds: the channels to keep, or — when `isExcluding` — the ones to drop.
    ///   - addedVideoIds: named videos, from any channel. They skip the shorts check.
    ///   - removedVideoIds: named videos to drop, out of the channels otherwise kept.
    ///   - channelExceptionIds: videos whose channel match doesn't count, see `QueueFilter.channelExceptionIds`.
    nonisolated static func getVideoFilter(
        subscriptionIds: [PersistentIdentifier],
        addedVideoIds: [String] = [],
        removedVideoIds: [String] = [],
        channelExceptionIds: [String] = [],
        isExcluding: Bool = false
    ) -> Predicate<Video>? {
        let shortsSettingRaw = Int(CloudKeyValueStore.shared.longLong(forKey: Const.defaultShortsSetting))
        let show = ShortsSetting.show.rawValue
        let defaultSetting = ShortsSetting.defaultSetting.rawValue

        if !channelExceptionIds.isEmpty {
            if isExcluding {
                return #Predicate<Video> { video in
                    !removedVideoIds.contains(video.youtubeId)
                        && (video.subscription.flatMap { sub in
                            (!subscriptionIds.contains(sub.persistentModelID)
                                || channelExceptionIds.contains(video.youtubeId))
                                && (!(video.isYtShort ?? false)
                                        || (sub._shortsSetting == defaultSetting
                                                ? shortsSettingRaw
                                                : sub._shortsSetting) == show)
                        } ?? true)
                }
            }
            return #Predicate<Video> { video in
                addedVideoIds.contains(video.youtubeId)
                    || (video.subscription.flatMap { sub in
                        subscriptionIds.contains(sub.persistentModelID)
                            && !channelExceptionIds.contains(video.youtubeId)
                            && (!(video.isYtShort ?? false)
                                    || (sub._shortsSetting == defaultSetting
                                            ? shortsSettingRaw
                                            : sub._shortsSetting) == show)
                    }) == true
            }
        }

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
