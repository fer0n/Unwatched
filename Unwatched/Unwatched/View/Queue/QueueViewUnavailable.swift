//
//  QueueViewUnavailable.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct QueueViewUnavailable: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var body: some View {
        ContentUnavailableView {
            Label("noQueueItems", systemImage: "rectangle.stack.badge.play.fill")
        } description: {
            Text("noQueueItemsDescription")
        } actions: {
            SetupShareSheetAction()
                .buttonStyle(.borderedProminent)
                .foregroundStyle(theme.contrastColor)
                .tint(theme.color)

            AddFeedsMenu()
                .bold()
                .foregroundStyle(theme.contrastColor)
                .tint(theme.color)
        }
        .contentShape(Rectangle())
        .handleVideoUrlDrop(.queue)
    }
}
