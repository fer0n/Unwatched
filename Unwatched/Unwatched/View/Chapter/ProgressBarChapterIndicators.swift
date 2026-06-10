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

    var breakWidth: CGFloat {
        let chapters = video?.sortedChapters ?? []
        return chapters.count > 40 ? 1 : 2
    }

    var body: some View {
        let chapters = video?.sortedChapters ?? []

        ForEach(chapters) { chapter in
            if !chapter.isActive {
                inactive(chapter)
            }
            if chapter.startTime != 0 {
                Color.white
                    .frame(width: breakWidth)
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
