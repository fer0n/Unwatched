import SwiftUI
import SwiftData
import UnwatchedShared

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.sideloadingSortOrder) var sideloadingSortOrder: VideoSorting = .createdDate

    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]
    let sortingOptions: [VideoSorting] = [.createdDate, .publishedDate]

    var body: some View {

        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            if subs.isEmpty {
                ContentUnavailableView("noSideloadedSubscriptions",
                                       systemImage: "arrow.right.circle",
                                       description: Text("noSideloadedSubscriptionsDetail"))
            } else {
                List {
                    ForEach(sortedVideos) { video in
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
                .listStyle(.plain)
                .myNavigationTitle("sideloads")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(sortingOptions, id: \.self) { sort in
                        Button(sort.description, systemImage: sort.systemName) {
                            sideloadingSortOrder = sort
                        }
                        .disabled(sideloadingSortOrder == sort)
                    }
                } label: {
                    Image(systemName: sideloadingSortOrder == .createdDate
                            ? Const.filterEmptySF
                            : Const.filterSF)
                }
                .accessibilityLabel("videoSorting")
            }
        }
    }

    var sortedVideos: [Video] {
        let videos = subs.flatMap { $0.videos ?? [] }
        let past = Date.distantPast
        switch sideloadingSortOrder {
        case .createdDate:
            return videos.sorted(by: { ($0.createdDate ?? $0.publishedDate ?? past)
                                    > $1.createdDate ?? $1.publishedDate ?? past })
        case .publishedDate:
            return videos.sorted(by: { $0.publishedDate ?? past > $1.publishedDate ?? past })
        case .clearedInboxDate:
            return videos.sorted(by: { $0.clearedInboxDate ?? past > $1.clearedInboxDate ?? past })
        }
    }

    var subs: [Subscription] {
        sidedloadedSubscriptions.filter({ $0.videos?.isEmpty == false })
    }

}

// #Preview {
//    SideloadingView()
// }
