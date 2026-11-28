//
//  YearReviewMediaSplit.swift
//  Unwatched
//

import SwiftUI
import Charts
import UnwatchedShared

struct YearReviewMediaSplit: View {
    let review: YearReview
    let images: [String: StatsChannelImage]
    let isActive: Bool
    var skipped = false

    static let duration = 3.0

    @State private var revealed = false
    @State private var emphasized = false

    var body: some View {
        let podcastsWin = review.podcastTime >= review.videoTime
        let winnerTime = podcastsWin ? review.podcastTime : review.videoTime
        VStack(spacing: 30) {
            ReviewCaption(text: Text("yearReviewMediaSplit"))
            Chart {
                sector(review.podcastTime, isWinner: podcastsWin)
                sector(review.videoTime, isWinner: !podcastsWin)
                unrevealedRemainder
            }
            .frame(width: 220, height: 220)
            .overlay {
                VStack(spacing: 2) {
                    CountUpText(target: winnerTime / review.totalTime, isOn: revealed) {
                        $0.formatted(.percent.precision(.fractionLength(0)))
                    }
                    .font(.system(size: 40, weight: .black))
                    Text(podcastsWin ? LocalizedStringKey("yearReviewAudioPodcasts") : "yearReviewVideosLabel")
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            HStack(alignment: .top, spacing: 30) {
                side(
                    Text("yearReviewVideosLabel"),
                    time: review.videoTime,
                    top: review.topVideoChannels,
                    isWinner: !podcastsWin
                )
                side(
                    Text("yearReviewAudioPodcasts"),
                    time: review.podcastTime,
                    top: review.topPodcasts,
                    isWinner: podcastsWin
                )
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: emphasized) { $1 && !skipped }
        .reviewAnimation(isActive: isActive, skipped: skipped) {
            revealed = false
            emphasized = false
        } finish: {
            revealed = true
            emphasized = true
        } animate: {
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.8)) { revealed = true }
            try? await Task.sleep(for: .seconds(1.9))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.8, bounce: 0.35)) { emphasized = true }
        }
    }

    private var unrevealedRemainder: some ChartContent {
        SectorMark(angle: .value("time", revealed ? 0 : review.totalTime), innerRadius: .ratio(0.62))
            .foregroundStyle(.clear)
    }

    private func sector(_ time: TimeInterval, isWinner: Bool) -> some ChartContent {
        SectorMark(
            angle: .value("time", revealed ? time : 0),
            innerRadius: .ratio(isWinner && emphasized ? 0.56 : 0.62),
            outerRadius: .ratio(isWinner && emphasized ? 1 : 0.92),
            angularInset: 2
        )
        .foregroundStyle(.white.opacity(isWinner ? 1 : 0.4))
        .cornerRadius(4)
    }

    private func side(_ label: Text, time: TimeInterval, top: [ChannelStat], isWinner: Bool) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white.opacity(isWinner ? 1 : 0.4))
                        .frame(width: 10, height: 10)
                    label
                        .font(.headline)
                }
                Text(YearReviewFormat.hours(time))
                    .font(.subheadline)
                    .opacity(0.75)
            }
            .scaleEffect(isWinner && emphasized ? 1.15 : 1)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(top) { channel in
                    HStack(spacing: 8) {
                        YearReviewChannelImage(channelId: channel.channelId, images: images, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(channel.channelName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(YearReviewFormat.hours(channel.watchTime))
                                .font(.caption2)
                                .monospacedDigit()
                                .opacity(0.75)
                        }
                    }
                }
            }
            .frame(maxWidth: 150, alignment: .leading)
            .opacity(emphasized ? 1 : 0)
        }
    }
}
