//
//  DeferRequestSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DeferRequest: Identifiable {
    let id = UUID()
    let video: Video
    let context: VideoListContext
    /// Runs after the sheet is dismissed
    var onDeferred: (() -> Void)?
}

/// One sheet on `MenuView` instead of one per row
private struct DeferRequestSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @State private var deferred: DeferRequest?

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(item: $navManager.deferRequest, onDismiss: handleDismiss) { request in
                DeferDateSheetContent(
                    video: request.video,
                    detectedDate: .constant(request.video.upcomingStartDate),
                    onSuccess: {
                        Signal.videoAction("defer", request.context)
                        deferred = request
                    }
                )
            }
    }

    private func handleDismiss() {
        deferred?.onDeferred?()
        deferred = nil
    }
}

extension View {
    func deferRequestSheet() -> some View {
        modifier(DeferRequestSheet())
    }
}
