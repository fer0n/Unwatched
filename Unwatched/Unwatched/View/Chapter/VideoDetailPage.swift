//
//  VideoDetailPage.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct VideoDetailRoute: Hashable, Codable {
    let videoId: PersistentIdentifier

    init(_ video: Video) {
        videoId = video.persistentModelID
    }
}

struct VideoDetailPage: View {
    @Query private var videos: [Video]

    init(_ route: VideoDetailRoute) {
        let videoId = route.videoId
        _videos = Query(filter: #Predicate<Video> { $0.persistentModelID == videoId })
    }

    var body: some View {
        ZStack {
            MyBackgroundColor(macOS: false)
            if let video = videos.first {
                ChapterDescriptionView(video: video, isTransparent: Device.isVision)
                    .environment(\.isInMenuStack, true)
            } else {
                ContentUnavailableView("noVideoFound", systemImage: "questionmark.video")
            }
        }
        .myNavigationTitle()
        .appNotificationOverlay(topPadding: 10)
        #if os(macOS)
        .sidebarPage()
        #endif
    }
}

extension View {
    func videoDetailDestination() -> some View {
        navigationDestination(for: VideoDetailRoute.self) { route in
            VideoDetailPage(route)
        }
    }
}
