//
//  VideoListItemSwipeActionsView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct LeadingSwipeActionsView: View {
    var color: Color
    var config: VideoListItemConfig
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var toggleIsNew: () -> Void

    var body: some View {
        // swipe actions ignore .accessibilityLabel; VoiceOver reads the title
        Group {
            Button("queueNext", systemImage: Const.queueNextSF, role: config.queueRole, action: addVideoToTopQueue)
                .tint(color.swipeShade(.light))
            Button("queueLast", systemImage: Const.queueLastSF, role: config.queueRole, action: addVideoToBottomQueue)
                .tint(color.swipeShade(.medium))
            if config.isNew == true {
                Button("removeIsNew", systemImage: Const.removeNewSF, action: toggleIsNew)
                    .tint(color.swipeShade(.dark))
            }
        }
        .labelStyle(.iconOnly)
    }
}

struct TrailingSwipeActionsView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) var modelContext

    var videoData: VideoData
    var color: Color
    var config: VideoListItemConfig
    var clearVideoEverywhere: () -> Void
    var setWatched: (Bool) -> Void
    var addVideoToTopQueue: () -> Void
    var addVideoToBottomQueue: () -> Void
    var toggleBookmark: () -> Void
    var toggleIsNew: () -> Void
    var moveToInbox: () -> Void
    var clearList: (ClearList, ClearDirection) -> Void
    var canBeCleared: Bool
    var deleteVideo: () -> Void

    var body: some View {
        Group {
            if canBeCleared {
                Button(
                    "clearVideo",
                    systemImage: Const.clearNoFillSF,
                    role: config.clearRole,
                    action: clearVideoEverywhere
                )
                .labelStyle(.iconOnly)
                .tint(color.swipeShade(.dark))
            }
            #if os(iOS)
            TrailingSwipeMoreMenu(
                videoData: videoData,
                color: color,
                config: config,
                setWatched: setWatched,
                addVideoToTopQueue: addVideoToTopQueue,
                addVideoToBottomQueue: addVideoToBottomQueue,
                clearVideoEverywhere: clearVideoEverywhere,
                canBeCleared: canBeCleared,
                toggleBookmark: toggleBookmark,
                toggleIsNew: toggleIsNew,
                moveToInbox: moveToInbox,
                clearList: clearList,
                deleteVideo: deleteVideo
            )
            #endif
            Button {
                guard let video = VideoService.getVideoModel(
                    from: videoData,
                    modelContext: modelContext
                ) else {
                    Log.error("No video to show details for")
                    return
                }
                navManager.pushVideoDetail(video)
                video.isNew = false
            } label: {
                Label("videoDescription", image: Const.videoDescriptionSF)
            }
            .labelStyle(.iconOnly)
            .tint(color.swipeShade(.light))
        }
    }
}

extension EnvironmentValues {
    @Entry var swipeActionColor: Color?
}

extension Color {
    enum SwipeShade: Double {
        case light = 0.1
        case medium = 0.3
        case dark = 0.5
    }

    func swipeShade(_ shade: SwipeShade) -> Color {
        mix(with: .black, by: shade.rawValue)
    }

    // swipe action icons are always white
    var darkenedForSwipeActions: Color {
        var base = self
        var lightest = base.swipeShade(.light)
        for _ in 0..<10 {
            guard !lightest.prefersWhiteText else { break }
            base = lightest
            lightest = base.swipeShade(.light)
        }
        return base
    }
}
