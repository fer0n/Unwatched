//
//  YearReviewTopDays.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewTopDays: View {
    static func duration(count: Int) -> Double {
        0.4 + 1.3 * Double(max(count - 1, 0)) + 1.2
    }

    let days: [WatchTimePoint]
    let isActive: Bool
    var skipped = false

    @State private var revealed = 0

    var body: some View {
        VStack(spacing: 26) {
            ReviewCaption(text: Text("yearReviewTopDays"))
            ForEach(Array(days.enumerated()), id: \.offset) { rank, day in
                let isVisible = rank >= days.count - revealed
                VStack(spacing: 4) {
                    Text(day.date, format: YearReviewFormat.gmt(.dateTime.day().month(.wide)))
                        .font(rank == 0 ? .system(size: 52, weight: .black) : .title.bold())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    CountUpText(
                        target: day.time,
                        isOn: isVisible,
                        format: YearReviewFormat.countingHours(target: day.time)
                    )
                    .font(rank == 0 ? .title3 : .body)
                    .opacity(0.8)
                    .countUp(isVisible, duration: 1.2, delay: 0)
                }
                .opacity(isVisible ? (rank == 0 ? 1 : 0.8) : 0)
                .scaleEffect(isVisible ? 1 : 0.6)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: revealed) { $1 > $0 && !skipped }
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            revealed = 0
        } finish: {
            revealed = days.count
        } animate: {
            for count in 1...max(days.count, 1) {
                try? await Task.sleep(for: .seconds(count == 1 ? 0.4 : 1.3))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.7, bounce: 0.3)) { revealed = count }
            }
        }
    }
}
