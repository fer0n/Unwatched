import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext

    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    var body: some View {
        let subs = sidedloadedSubscriptions.filter({ $0.videos?.isEmpty == false })

        ZStack {
            if subs.isEmpty {
                ContentUnavailableView("noSideloadedSubscriptions",
                                       systemImage: "arrow.right.circle",
                                       description: Text("noSideloadedSubscriptionsDetail"))
            } else {
                let videos = subs.flatMap { $0.videos ?? [] }
                let past = Date.distantPast
                let sortedVideos = videos.sorted(by: { $0.publishedDate ?? past > $1.publishedDate ?? past })
                List {
                    ForEach(sortedVideos) { video in
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
                .listStyle(.plain)
                .navigationTitle("sideloads")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// #Preview {
//    SideloadingView()
// }
