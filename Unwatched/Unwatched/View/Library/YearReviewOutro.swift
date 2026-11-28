//
//  YearReviewOutro.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct YearReviewOutro: View {
    let review: YearReview
    let images: [String: StatsChannelImage]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("yearReviewOutro \(String(review.year))")
                    .font(.system(size: 36, weight: .black))
                Text("yearReviewOutroSubtitle")
                    .font(.headline)
                    .opacity(0.8)
            }
            .multilineTextAlignment(.center)
            gap
            Grid(horizontalSpacing: 12, verticalSpacing: 18) {
                GridRow {
                    summary(YearReviewFormat.hours(review.totalTime), "yearReviewTotalCaption", "clock.fill")
                    countSummary
                    summary(YearReviewFormat.days(review.longestStreak), "yearReviewStreak", "flame.fill")
                }
                GridRow {
                    summary(review.activeDays.formatted(), "yearReviewActiveDays", "calendar")
                    summary(
                        YearReviewFormat.monthName(review.busiestMonthIndex),
                        "yearReviewBusiestMonth",
                        "chart.bar.fill"
                    )
                    if let day = review.topDays.first {
                        summary(
                            day.date.formatted(YearReviewFormat.gmt(.dateTime.day().month(.abbreviated))),
                            "yearReviewBiggestDay",
                            "star.fill"
                        )
                    }
                }
            }
            if !review.topChannels.isEmpty {
                gap
                topChannels
            }
        }
    }

    private var gap: some View {
        Spacer(minLength: 28).frame(maxHeight: 64)
    }

    @ViewBuilder
    private var countSummary: some View {
        if review.videosWatched > 0 {
            summary(review.videosWatched.formatted(), "yearReviewVideosLabel", "checkmark.circle.fill")
        } else if review.episodesWatched > 0 {
            summary(review.episodesWatched.formatted(), "yearReviewAudioPodcasts", "headphones")
        } else {
            summary(review.channelCount.formatted(), "yearReviewChannels", "person.2.fill")
        }
    }

    private var topChannels: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("yearReviewTopChannels")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.75)
                .frame(maxWidth: .infinity)
            ForEach(Array(review.topChannels.enumerated()), id: \.element.channelId) { rank, channel in
                HStack(spacing: 10) {
                    Text(verbatim: "\(rank + 1)")
                        .font(.headline)
                        .monospacedDigit()
                        .frame(width: 18)
                    YearReviewChannelImage(channelId: channel.channelId, images: images, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(channel.channelName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(YearReviewFormat.hours(channel.watchTime))
                            .font(.caption)
                            .monospacedDigit()
                            .opacity(0.75)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private func summary(_ value: String, _ label: LocalizedStringKey, _ systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.title3)
                .opacity(0.85)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .opacity(0.7)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
