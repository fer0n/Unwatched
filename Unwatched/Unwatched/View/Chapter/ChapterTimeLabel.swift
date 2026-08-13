//
//  ChapterTimeLabel.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterTimeLabel: View {
    var chapter: SendableChapter
    @Environment(PlayerManager.self) var player

    var body: some View {
        let isCurrent = chapter.chapterId == player.currentChapter?.chapterId
        let currentTime = isCurrent ? player.currentTime : nil
        let timeInfo = ChapterListItem.ChapterTimeInfo(chapter: chapter, currentTime: currentTime)

        if let short = timeInfo.short, let verbose = timeInfo.verbose {
            Text(short)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityElement()
                .accessibilityLabel(verbose)
        }
    }
}
