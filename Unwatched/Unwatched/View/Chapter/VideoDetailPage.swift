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
    @Environment(NavigationManager.self) private var navManager
    @Query private var videos: [Video]
    private let videoId: PersistentIdentifier

    init(_ route: VideoDetailRoute) {
        let videoId = route.videoId
        self.videoId = videoId
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
        .channelPageColor(
            imageUrl: videos.first?.channelColorImageUrl,
            choice: videos.first?.channelColorChoice ?? .automatic
        )
        .appNotificationOverlay(topPadding: 10)
        .onAppear {
            navManager.visibleChannelPages.insert(videoId)
        }
        .onDisappear {
            navManager.visibleChannelPages.remove(videoId)
        }
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
