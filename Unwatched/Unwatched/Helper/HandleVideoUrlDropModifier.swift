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
            player.loadTopmostVideoFromQueue(after: task)
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

// MARK: DynamicViewContent

struct HandleDynamicVideoURLDropView<Content: DynamicViewContent>: DynamicViewContent {
    @Environment(PlayerManager.self) private var player

    var placement: VideoPlacementArea
    let content: Content

    init(placement: VideoPlacementArea, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.placement = placement
    }

    var body: some View {
        content
            .dropDestination(for: URL.self) { items, index in
                handleUrlDrop(items, index)
            }
    }

    func handleUrlDrop(_ items: [URL], _ index: Int) {
        Log.info("handleUrlDrop \(items)")
        let task = VideoService.addForeignUrls(items, in: placement, at: index)
        if placement == .queue && index == 0 {
            player.loadTopmostVideoFromQueue(after: task)
        }
    }

    // DynamicViewContent conformance
    var data: Content.Data { content.data }
}

extension DynamicViewContent {
    @MainActor
    func handleDynamicVideoURLDrop(_ placement: VideoPlacementArea) -> some DynamicViewContent {
        HandleDynamicVideoURLDropView(placement: placement) {
            self
        }
    }
}
