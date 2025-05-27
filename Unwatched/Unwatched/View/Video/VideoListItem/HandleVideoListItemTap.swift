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
            #if os(iOS)
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
        #else
        .overlay(TapHandler(onTap: handleTap))
        #endif
    }

    func handleTap() {
        guard let video = VideoService.getVideoModel(
            from: videoData,
            modelContext: modelContext
        ) else {
            Log.error("no video to tap")
            return
        }
        Task {
            VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        }
        player.playVideo(video)
        navManager.handlePlay()
    }
}

#if os(macOS)
// workaround: .tapGesture breaks .onMove on macOS
class TapHandlerView: NSView {
    var onTap: () -> Void
    private var mouseDownLocation: NSPoint?

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        var keepOn = true
        var hasDraggedBeyondThreshold = false
        let startLocation = event.locationInWindow

        // Use a mouse-tracking loop as otherwise mouseUp events are not delivered
        while keepOn {
            guard let nextEvent = self.window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }

            switch nextEvent.type {
            case .leftMouseDragged:
                if !hasDraggedBeyondThreshold {
                    let deltaX = abs(nextEvent.locationInWindow.x - startLocation.x)
                    let deltaY = abs(nextEvent.locationInWindow.y - startLocation.y)
                    if deltaX > 3 || deltaY > 3 {
                        hasDraggedBeyondThreshold = true
                        super.mouseDown(with: event)
                        keepOn = false
                    }
                }

            case .leftMouseUp:
                onTap()
                keepOn = false
                return

            default: break
            }
        }
    }
}

struct TapHandler: NSViewRepresentable {
    let onTap: () -> Void

    func makeNSView(context: Context) -> TapHandlerView {
        TapHandlerView(onTap: onTap)
    }

    func updateNSView(_ nsView: TapHandlerView, context: Context) {
        nsView.onTap = onTap
    }
}
#endif

extension View {
    func handleVideoListItemTap(_ videoData: VideoData) -> some View {
        self.modifier(HandleVideoListItemTap(videoData: videoData))
    }
}
