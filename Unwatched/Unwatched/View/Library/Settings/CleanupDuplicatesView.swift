//
//  CleanupDuplicatesView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CleanupDuplicatesView: View {
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
            .myTint()

            if let info = cleanupInfo {
                Text("""
            removedDuplicates
            \(info.countVideos)
            \(info.countQueueEntries)
            \(info.countInboxEntries)
            \(info.countChapters)
            \(info.countSubscriptions)
            \(info.countWatchTimeEntries)
            """)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
