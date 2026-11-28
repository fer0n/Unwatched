//
//  YearReviewStreak.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewStreak: View {
    let streakDays: [Date]
    let watchedDays: Set<Date>
    let reviewedDays: ClosedRange<Date>
    let isActive: Bool
    var skipped = false

    @State private var filled = 0

    var body: some View {
        VStack(spacing: 12) {
            ReviewCaption(text: Text("yearReviewStreak"))
            Text(YearReviewFormat.days(streakDays.count))
                .hidden()
                .overlay {
                    Text(YearReviewFormat.days(filled))
                        .transaction { $0.animation = nil }
                }
                .font(.system(size: 56, weight: .black))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if let first = streakDays.first, let last = streakDays.last {
                Text(dateRange(first, last))
                    .font(.subheadline)
                    .opacity(0.75)
            }
            if let days = calendarDays {
                YearReviewCalendar(days: days, heightBudget: 320, opacity: opacity)
                    .padding(.top, 6)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: filledMonthEnds) { $1 > $0 && !skipped }
        .sensoryFeedback(.impact(weight: .heavy), trigger: filled == streakDays.count) { $1 && filled > 0 && !skipped }
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            filled = 0
        } finish: {
            filled = streakDays.count
        } animate: {
            await run()
        }
    }

    /// The streak's weeks and one either side.
    private var calendarDays: ClosedRange<Date>? {
        let calendar = YearReviewCalendar.calendar
        guard let first = streakDays.first,
              let last = streakDays.last,
              let streakStart = calendar.dateInterval(of: .weekOfYear, for: first)?.start,
              let streakEnd = calendar.dateInterval(of: .weekOfYear, for: last)?.end,
              let start = calendar.date(byAdding: .day, value: -7, to: streakStart),
              let end = calendar.date(byAdding: .day, value: 6, to: streakEnd) else { return nil }
        let lower = max(start, reviewedDays.lowerBound)
        let upper = min(end, reviewedDays.upperBound)
        return lower <= upper ? lower...upper : nil
    }

    private var filledMonthEnds: Int {
        let calendar = YearReviewCalendar.calendar
        return streakDays.prefix(filled).filter { day in
            calendar.date(byAdding: .day, value: 1, to: day).map { calendar.component(.day, from: $0) == 1 } ?? false
        }.count
    }

    private func opacity(for day: Date) -> Double {
        let firstDay = streakDays.first ?? .distantPast
        let index = YearReviewCalendar.calendar.dateComponents([.day], from: firstDay, to: day).day ?? -1
        if index >= 0 && index < streakDays.count {
            return index < filled ? 1 : 0.15
        }
        return watchedDays.contains(day) ? 0.3 : 0.08
    }

    private func dateRange(_ first: Date, _ last: Date) -> String {
        let style = YearReviewFormat.gmt(.dateTime.day().month(.abbreviated))
        return "\(first.formatted(style)) – \(last.formatted(style))"
    }

    static func duration(count: Int) -> Double {
        0.5 + Double(count) * dayStep(count) + 0.2
    }

    private static func dayStep(_ count: Int) -> Double {
        min(0.15, 2.8 / Double(max(count, 1)))
    }

    private func run() async {
        let count = streakDays.count
        guard count > 0 else { return }
        let step = Self.dayStep(count)
        try? await Task.sleep(for: .seconds(0.5))
        for day in 1...count {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { filled = day }
            try? await Task.sleep(for: .seconds(step))
        }
    }
}
