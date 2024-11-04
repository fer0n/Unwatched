//
//  HandleVideoListItemTab.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct HandleVideoListItemTap: ViewModifier {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) private var player

    let videoData: VideoData

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                guard let video = VideoService.getVideoModel(
                    from: videoData,
                    modelContext: modelContext
                ) else {
                    Logger.log.error("no video to tap")
                    return
                }
                Task {
                    VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
                }
                player.playVideo(video)
                navManager.handlePlay()
            }
    }
}

extension View {
    func handleVideoListItemTap(_ videoData: VideoData) -> some View {
        self.modifier(HandleVideoListItemTap(videoData: videoData))
    }
}
