//
//  HandleVideoListItemTab.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct HandleVideoListItemTap: ViewModifier {
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.rotateOnPlay) var rotateOnPlay: Bool = false
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = false

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
                    _ = VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
                }
                player.playVideo(video)
                if hideMenuOnPlay || rotateOnPlay {
                    withAnimation {
                        navManager.showMenu = false
                    }
                }

                if returnToQueue {
                    navManager.navigateToQueue()
                }
            }
    }
}

extension View {
    func handleVideoListItemTap(_ videoData: VideoData) -> some View {
        self.modifier(HandleVideoListItemTap(videoData: videoData))
    }
}
