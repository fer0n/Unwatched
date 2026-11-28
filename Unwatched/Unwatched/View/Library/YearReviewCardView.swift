//
//  YearReviewCardView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewCardView: View {
    let card: YearReviewCard
    let review: YearReview?
    let isLoading: Bool
    let images: [String: StatsChannelImage]
    let media: YearReviewMedia
    let isActive: Bool
    let skipped: Bool
    let skipCount: Int

    var body: some View {
        if let review {
            content(review)
                .id(skipCount)
        } else if isLoading {
            ProgressView()
        }
    }

    @ViewBuilder
    private func content(_ review: YearReview) -> some View {
        switch card {
        case .intro: intro(review)
        case .totalTime: totalTime(review).landingHaptic(isActive && !skipped, after: card.duration(for: review))
        case .videos: videos(review).landingHaptic(isActive && !skipped, after: card.duration(for: review))
        case .topChannels, .tags: race(review)
        case .mediaSplit:
            YearReviewMediaSplit(review: review, images: images, isActive: isActive, skipped: skipped)
        case .busiestMonth:
            YearReviewBusiestMonth(
                months: review.months,
                busiest: review.busiestMonthIndex,
                isActive: isActive,
                skipped: skipped
            )
        case .topDays: YearReviewTopDays(days: review.topDays, isActive: isActive, skipped: skipped)
        case .daysWatched:
            YearReviewActiveDays(review: review, isActive: isActive, skipped: skipped)
                .landingHaptic(isActive && !skipped, after: card.duration(for: review))
        case .streak:
            YearReviewStreak(
                streakDays: review.streakDays,
                watchedDays: review.watchedDays,
                reviewedDays: review.reviewedDays,
                isActive: isActive,
                skipped: skipped
            )
        case .outro: YearReviewOutro(review: review, images: images).landingHaptic(isActive && !skipped, after: 0.3)
        }
    }

    @ViewBuilder
    private func race(_ review: YearReview) -> some View {
        if card == .topChannels {
            YearReviewRace(
                caption: Text("yearReviewTopChannels"),
                entries: review.channelRace[media] ?? [],
                stepMonths: review.raceStepMonths,
                isActive: isActive,
                skipped: skipped
            ) {
                YearReviewChannelImage(channelId: $0.id, images: images, size: $1)
            }
            .id(media)
        } else {
            YearReviewRace(
                caption: Text("yearReviewTags"),
                entries: review.tagRace,
                stepMonths: review.raceStepMonths,
                isActive: isActive,
                skipped: skipped
            ) { entry, size in
                Image(systemName: entry.symbol ?? "tag.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
                    .frame(width: size, height: size)
            }
        }
    }

    @ViewBuilder
    private func intro(_ review: YearReview) -> some View {
        let year = String(review.year)
        if review.totalTime > 0 {
            headline(Text("yearReviewIntro \(year)"), subtitle: Text("yearReviewIntroSubtitle"))
        } else {
            headline(Text(verbatim: year), subtitle: Text("yearReviewEmpty"))
        }
    }

    private func totalTime(_ review: YearReview) -> some View {
        let hours = (review.totalTime / 3600).rounded(.down)
        let minutes = ((review.totalTime - hours * 3600) / 60).rounded(.down)
        return VStack(spacing: 12) {
            ReviewCaption(text: Text("yearReviewTotalCaption"))
            CountUpText(
                target: review.totalTime,
                isOn: isActive,
                widest: totalTimeText(hours * 3600 + 59 * 60, hours: hours, minutes: max(minutes, 10))
            ) { value in
                totalTimeText(value, hours: hours, minutes: minutes)
            }
            .font(.system(size: 64, weight: .black))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .countUp(isActive, duration: CountUpTiming.totalTimeDuration)
            VStack(spacing: 4) {
                Text("yearReviewTotalDays \(fullDays(review.totalTime))")
                Text("yearReviewPerDay \(YearReviewFormat.hours(review.totalTime / Double(max(review.daysInYear, 1))))")
            }
            .font(.title3)
            .opacity(0.8)
            .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
    }

    private func videos(_ review: YearReview) -> some View {
        VStack(spacing: 50) {
            if review.videosWatched > 0 {
                stat(caption: Text("yearReviewVideos"), value: count(review.videosWatched))
            }
            if review.episodesWatched > 0 {
                stat(caption: Text("yearReviewEpisodes"), value: count(review.episodesWatched))
            }
        }
    }

    private func count(_ value: Int) -> some View {
        CountUpText(target: Double(value), isOn: isActive) { Int($0.rounded()).formatted() }
            .countUp(isActive)
    }

    private func headline(_ title: Text, subtitle: Text) -> some View {
        VStack(spacing: 16) {
            title
                .font(.system(size: 44, weight: .black))
            subtitle
                .font(.title3)
                .opacity(0.8)
        }
        .multilineTextAlignment(.center)
    }

    private func stat(caption: Text, value: some View) -> some View {
        VStack(spacing: 12) {
            ReviewCaption(text: caption)
            value
                .font(.system(size: 64, weight: .black))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .multilineTextAlignment(.center)
    }

    private func totalTimeText(_ value: TimeInterval, hours: Double, minutes: Double) -> AttributedString {
        let unitFont = Font.system(size: 32, weight: .heavy)
        let shownHours = (value / 3600).rounded(.down)
        var text = AttributedString()
        if hours > 0 {
            text += YearReviewFormat.paddedNumber(
                shownHours * 3600, unit: .hours, digits: YearReviewFormat.digits(hours), unitFont: unitFont
            )
        }
        if minutes > 0 || hours == 0 {
            if hours > 0 { text += AttributedString(" ") }
            let shownMinutes = value - shownHours * 3600
            let digits = YearReviewFormat.digits(minutes)
            text += YearReviewFormat.paddedNumber(shownMinutes, unit: .minutes, digits: digits, unitFont: unitFont)
        }
        return text
    }

    private func fullDays(_ time: TimeInterval) -> String {
        (time / 86400).formatted(.number.precision(.fractionLength(1)))
    }
}

extension YearReviewCard {
    /// How long the slide's animation runs before it shows its final state.
    @MainActor
    func duration(for review: YearReview) -> Double {
        switch self {
        case .intro, .outro: 0
        case .totalTime: CountUpTiming.total(duration: CountUpTiming.totalTimeDuration)
        case .videos: CountUpTiming.total()
        case .topChannels, .tags: RaceTiming.duration(stepCount: review.raceStepMonths.count)
        case .mediaSplit: YearReviewMediaSplit.duration
        case .busiestMonth: YearReviewBusiestMonth.duration(busiest: review.busiestMonthIndex)
        case .topDays: YearReviewTopDays.duration(count: review.topDays.count)
        case .streak: YearReviewStreak.duration(count: review.streakDays.count)
        case .daysWatched: YearReviewActiveDays.duration
        }
    }
}
