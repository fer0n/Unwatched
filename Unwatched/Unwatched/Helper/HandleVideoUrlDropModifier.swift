//
//  HandleUrlDropModifier.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

// MARK: View

struct HandleVideoUrlDropModifier: ViewModifier {
    @Environment(PlayerManager.self) private var player

    var placement: VideoPlacementArea
    var isTargeted: ((_ targeted: Bool) -> Void)?

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self,
                             action: handleUrlDrop,
                             isTargeted: { targeted in isTargeted?(targeted) })
    }

    func handleUrlDrop(_ items: [URL], _ location: CGPoint) -> Bool {
        Log.info("handleUrlDrop \(items)")
        let task = VideoService.addForeignUrls(items, in: placement, at: 0)
        if placement == .queue {
            player.loadTopmostVideoFromQueue(after: task, filter: .all)
            Signal.playbackStarted("drop")
        }
        return true
    }
}

extension View {
    func handleVideoUrlDrop(
        _ placement: VideoPlacementArea,
        isTargeted: ((_ targeted: Bool) -> Void)? = nil
    ) -> some View {
        self.modifier(HandleVideoUrlDropModifier(placement: placement, isTargeted: isTargeted))
    }
}
