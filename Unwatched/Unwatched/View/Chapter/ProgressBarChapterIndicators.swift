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
            if !chapter.isActive {
                inactive(chapter)
            }
            if chapter.startTime != 0 {
                Color.white
                    .frame(width: 2)
                    .position(
                        x: (chapter.startTime / duration) * width,
                        y: height / 2
                    )
                    .blendMode(.destinationOut)
            }
        }
    }

    @ViewBuilder
    func inactive(_ chapter: Chapter) -> some View {
        if let chapterDuration = chapter.duration {
            let inactiveWidth = (chapterDuration / duration) * width
            let xPos = (chapter.startTime / duration) * width + (inactiveWidth / 2)

            Color.white
                .blendMode(.destinationOut)
                .frame(height: height / 2)
                .frame(width: inactiveWidth)
                .position(
                    x: xPos,
                    y: height / 4
                )
        }
    }
}
