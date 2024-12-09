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
        }
    }
}
