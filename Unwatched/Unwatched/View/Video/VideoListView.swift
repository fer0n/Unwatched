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
        let sorting = VideoListView.getVideoSorting(sort)
        _videos = Query(filter: filter, sort: sorting, animation: .default)
    }

    var body: some View {
        ForEach(videos) { video in
            VideoListItem(
                video,
                config: VideoListItemConfig(
                    showVideoStatus: true,
                    hasInboxEntry: video.inboxEntry != nil,
                    hasQueueEntry: video.queueEntry != nil,
                    watched: video.watchedDate != nil
                )
            )
        }
        .listRowBackground(Color.backgroundColor)
    }

    static func getVideoSorting(_ sort: VideoSorting?) -> [SortDescriptor<Video>] {
        switch sort {
        case .clearedInboxDate:
            return [
                SortDescriptor<Video>(\.clearedInboxDate, order: .reverse),
                SortDescriptor<Video>(\.publishedDate, order: .reverse)
            ]
        default:
            return [SortDescriptor<Video>(\.publishedDate, order: .reverse)]
        }
    }

    nonisolated static func getVideoFilter(_ subscriptionId: PersistentIdentifier? = nil,
                                           searchText: String = "") -> Predicate<Video>? {
        var filter: Predicate<Video>?
        let allSubscriptions = subscriptionId == nil

        let shortsSettingRaw = UserDefaults.standard.integer(forKey: Const.defaultShortsSetting)
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
}

// #Preview {
//    VideoListView()
// }
