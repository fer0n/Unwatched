//
//  YearReviewRace.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewRace<Leading: View>: View {
    let caption: Text
    let entries: [RaceEntry]
    let stepMonths: [Int]
    let isActive: Bool
    var skipped = false
    @ViewBuilder let leading: (RaceEntry, CGFloat) -> Leading

    @State private var step = -1
    @State private var finished = false

    var body: some View {
        let ranked = entries.sorted {
            (value($0), $0.total, $1.id) > (value($1), $1.total, $0.id)
        }
        let longest = max(ranked.first.map(value) ?? 0, 1)
        let hourDigits = YearReviewFormat.digits((entries.map(\.total).max() ?? 0) / 3600)

        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 4) {
                ReviewCaption(text: caption)
                Text(step >= 0 && step < stepMonths.count ? YearReviewFormat.monthName(stepMonths[step]) : " ")
                    .font(.headline)
                    .opacity(finished ? 0 : 0.75)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)

            ForEach(Array(ranked.enumerated()), id: \.element.id) { rank, entry in
                row(
                    entry,
                    rank: rank,
                    fraction: value(entry) / longest,
                    hourDigits: hourDigits,
                    isWinner: finished && rank == 0
                )
            }
        }
        .sensoryFeedback(.selection, trigger: ranked.map(\.id)) { _, _ in isActive && !finished && !skipped }
        .sensoryFeedback(.impact(weight: .heavy), trigger: finished) { $1 && !skipped }
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            step = -1
            finished = false
        } finish: {
            step = (entries.first?.cumulative.count ?? 0) - 1
            finished = true
        } animate: {
            await run()
        }
    }

    private func value(_ entry: RaceEntry) -> TimeInterval {
        step >= 0 && step < entry.cumulative.count ? entry.cumulative[step] : 0
    }

    private func row(
        _ entry: RaceEntry, rank: Int, fraction: Double, hourDigits: Int, isWinner: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(rank + 1)")
                .font(isWinner ? .largeTitle.bold() : .title2.bold())
                .monospacedDigit()
                .frame(width: 30)
                .contentTransition(.numericText())
            leading(entry, isWinner ? 84 : 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(isWinner ? .title2.bold() : .headline)
                    .lineLimit(1)
                DurationBar(fraction: fraction)
                Text(YearReviewFormat.timestamp(value(entry), hourDigits: hourDigits))
                    .font(.subheadline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .opacity(0.75)
            }
        }
        .padding(.vertical, isWinner ? 8 : 0)
    }

    private func run() async {
        let count = entries.first?.cumulative.count ?? 0
        guard count > 0 else { return }
        let duration = RaceTiming.stepDuration(count)
        try? await Task.sleep(for: .seconds(0.5))
        for next in 0..<count {
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) { step = next }
            try? await Task.sleep(for: .seconds(duration))
        }
        try? await Task.sleep(for: .seconds(RaceTiming.settleDelay))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.8, bounce: 0.3)) { finished = true }
    }
}

enum RaceTiming {
    static let settleDelay = 0.9

    static func duration(stepCount: Int) -> Double {
        0.5 + Double(stepCount) * stepDuration(stepCount) + settleDelay + 0.8
    }

    static func stepDuration(_ count: Int) -> Double {
        min(0.8, 15.0 / Double(max(count, 1)))
    }
}
