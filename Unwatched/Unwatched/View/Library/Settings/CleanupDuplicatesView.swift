//
//  CleanupDuplicatesView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CleanupDuplicatesView: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @State var cleanupInfo: RemovedDuplicatesInfo?

    var body: some View {
        MySection(footer: "removeDuplicatesHelper") {
            AsyncButton {
                let task = CleanupService.cleanupDuplicatesAndInboxDate(videoOnly: false)
                let value = await task.value
                withAnimation {
                    cleanupInfo = value
                }
            } label: {
                Text("removeDuplicates")
            }
            .tint(theme.color)

            if let info = cleanupInfo {
                Text("""
            removedDuplicates
            \(info.countVideos)
            \(info.countQueueEntries)
            \(info.countInboxEntries)
            \(info.countChapters)
            \(info.countSubscriptions)
            """)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
