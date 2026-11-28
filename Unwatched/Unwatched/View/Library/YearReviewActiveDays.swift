//
//  YearReviewActiveDays.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewActiveDays: View {
    let review: YearReview
    let isActive: Bool
    var skipped = false

    static let duration = CountUpTiming.total()

    @State private var lit = 0

    var body: some View {
        VStack(spacing: 16) {
            ReviewCaption(text: Text("yearReviewActiveDays"))
            CountUpText(target: Double(review.activeDays), isOn: isActive) { Int($0.rounded()).formatted() }
                .countUp(isActive)
                .font(.system(size: 64, weight: .black))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            DurationBar(fraction: isActive ? review.activeDaysShare : 0)
                .frame(maxWidth: 260)
                .countUp(isActive)
            CountUpText(target: review.activeDaysShare, isOn: isActive) {
                let share = $0.formatted(.percent.precision(.fractionLength(0)))
                return review.isCurrentYear
                    ? String(localized: "yearReviewActiveDaysShareSoFar \(share)")
                    : String(localized: "yearReviewActiveDaysShare \(share)")
            }
            .countUp(isActive)
            .font(.title3)
            .opacity(0.8)
            YearReviewCalendar(days: review.reviewedDays, heightBudget: 300) { day in
                guard let index = review.watchedDayOrder[day] else { return 0.08 }
                return index < lit ? 1 : 0.15
            }
            .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            lit = 0
        } finish: {
            lit = review.watchedDays.count
        } animate: {
            await run()
        }
    }

    private func run() async {
        let count = review.watchedDays.count
        guard count > 0 else { return }
        let steps = min(count, 60)
        try? await Task.sleep(for: .seconds(0.3))
        for step in 1...steps {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.15)) { lit = count * step / steps }
            try? await Task.sleep(for: .seconds(2.2 / Double(steps)))
        }
    }
}
