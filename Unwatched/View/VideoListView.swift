//
//  VideoListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct VideoListView: View {
    @AppStorage(Const.hideShorts) var hideShorts: Bool = false
    @Query var videos: [Video]

    init(subscriptionId: PersistentIdentifier? = nil,
         sort: VideoSorting? = nil,
         searchText: String = "") {
        let filter = VideoListView.getVideoFilter(showShorts: !hideShorts, subscriptionId, searchText)
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

    static func getVideoFilter(showShorts: Bool,
                               _ subscriptionId: PersistentIdentifier? = nil,
                               _ searchText: String = "") -> Predicate<Video>? {
        var filter: Predicate<Video>?
        let allSubscriptions = subscriptionId == nil

        if allSubscriptions {
            filter = #Predicate<Video> { video in
                (showShorts || video.isYtShort == false)
                    && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
            }
        } else {
            filter = #Predicate<Video> { video in
                video.subscription?.persistentModelID == subscriptionId &&
                    (showShorts || video.isYtShort == false)
                    && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
            }
        }
        return filter
    }

}

// #Preview {
//    VideoListView()
// }
