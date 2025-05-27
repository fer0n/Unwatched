//
//  AutoMarkSeenViewModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct AutoMarkSeenViewModifier: ViewModifier {
    @AppStorage(Const.autoRemoveNew) var autoRemoveNew: Bool = true
    var video: VideoData

    func body(content: Content) -> some View {
        content
            .onDisappear {
                if autoRemoveNew, video.isNew == true {
                    guard let videoId = video.persistentId else {
                        Log.warning("AutoMarkSeenViewModifier: no videoId")
                        return
                    }
                    _ = withAnimation {
                        VideoService.setIsNew(videoId, false)
                    }
                }
            }
    }
}

extension View {
    func autoMarkSeen(_ video: VideoData) -> some View {
        modifier(AutoMarkSeenViewModifier(video: video))
    }
}
