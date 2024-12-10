//
//  ProgressBarChapterIndicators.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ProgressBarChapterIndicators: View {
    let video: Video?
    let height: CGFloat
    let width: CGFloat
    let duration: Double

    var body: some View {
        ForEach(video?.sortedChapters ?? []) { chapter in
            if chapter.startTime != 0 {
                Color.playerBackgroundColor
                    .rotationEffect(.degrees(180))
                    .frame(width: 2)
                    .position(
                        x: (chapter.startTime / duration) * width,
                        y: height / 2
                    )
            }
            if !chapter.isActive {
                inactive(chapter)
                    .opacity(0.3)
            }
        }
    }

    @ViewBuilder
    func inactive(_ chapter: Chapter) -> some View {
        if let chapterDuration = chapter.duration {
            let inactiveWidth = (chapterDuration / duration) * width

            Color.playerBackgroundColor
                .frame(width: inactiveWidth)
                .position(
                    x: (chapter.startTime / duration) * width + (inactiveWidth / 2),
                    y: height / 2
                )
        }
    }
}
