//
//  VideoListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct VideoListView: View {
    @Query var videos: [Video]

    init(subscriptionId: PersistentIdentifier? = nil,
         ytShortsFilter: ShortsDetection? = nil,
         sort: VideoSorting? = nil,
         searchText: String = "") {
        let filter = VideoListView.getVideoFilter(subscriptionId, ytShortsFilter, searchText)
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
                    watched: video.watched
                )
            )
        }
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

    static func getVideoFilter(_ subscriptionId: PersistentIdentifier? = nil,
                               _ ytShortsFilter: ShortsDetection? = nil,
                               _ searchText: String = "") -> Predicate<Video>? {
        var filter: Predicate<Video>?
        let allSubscriptions = subscriptionId == nil
        if allSubscriptions {
            switch ytShortsFilter {
            case .safe:
                filter = #Predicate<Video> { video in
                    video.isYtShort == false
                        && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
                }
            case .moderate:
                filter = #Predicate<Video> { video in
                    (video.isYtShort == false && video.isLikelyYtShort == false)
                        && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
                }
            case .none:
                break
            }
        } else {
            switch ytShortsFilter {
            case .safe:
                filter = #Predicate<Video> { video in
                    video.subscription?.persistentModelID == subscriptionId &&
                        video.isYtShort == false
                        && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
                }
            case .moderate:
                filter = #Predicate<Video> { video in
                    video.subscription?.persistentModelID == subscriptionId &&
                        (video.isYtShort == false && video.isLikelyYtShort == false)
                        && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
                }
            case .none:
                filter = #Predicate<Video> { video in
                    video.subscription?.persistentModelID == subscriptionId
                        && (searchText.isEmpty || video.title.localizedStandardContains(searchText))
                }
            }
        }
        return filter
    }

}

// #Preview {
//    VideoListView()
// }
