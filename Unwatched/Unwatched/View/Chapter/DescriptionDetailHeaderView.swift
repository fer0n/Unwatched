//
//  DescriptionDetailHeaderView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionDetailHeaderView: View {
    @State var hapticToggle = false

    let video: Video
    var showProgress = true
    let onTitleTap: () -> Void

    private var titleGap: CGFloat { showProgress ? 16 : 0 }
    private var chapterGap: CGFloat { showProgress ? 24 : 0 }

    var body: some View {
        if showProgress, let duration = video.duration, duration > 0 {
            VideoDetailProgress(elapsed: video.elapsedSeconds ?? 0, duration: duration)
                .padding(.bottom, 2)
        }

        Button {
            onTitleTap()
        } label: {
            Text(verbatim: video.title)
                .font(.title)
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .contextMenu {
            CopyUrlOptions(asSection: true, video: video, onSuccess: {
                hapticToggle.toggle()
            })
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .padding(.top, titleGap)

        HStack(alignment: .center) {
            if video.subscription != nil {
                InteractiveSubscriptionTitle(
                    subscription: video.subscription,
                    showImage: true,
                    imageSize: 36,
                    subtitle: publishedText
                )
                .equatable()
                .lineLimit(1)
            } else if let publishedText {
                Text(verbatim: publishedText)
            }
            Spacer(minLength: 0)
            VideoDetailStatusIcons(video: video)
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.bottom, chapterGap)
    }

    /// e.g. "25 Sep · 14h ago"; the year only once it's not the current one
    var publishedText: String? {
        guard let published = video.publishedDate else { return nil }
        let isThisYear = Calendar.current.isDate(published, equalTo: .now, toGranularity: .year)
        let date = isThisYear
            ? published.formatted(.dateTime.day().month(.abbreviated))
            : published.formatted(.dateTime.day().month(.abbreviated).year())
        return "\(date) · \(published.formattedRelative)"
    }
}

/// Elapsed time, bar and total length in one row, like a scrubber
private struct VideoDetailProgress: View {
    let elapsed: Double
    let duration: Double

    var body: some View {
        let elapsed = min(max(elapsed, 0), duration)
        HStack(spacing: 10) {
            Text(verbatim: elapsed.formattedSecondsColon)
            GeometryReader { geo in
                Capsule()
                    .fill(.quaternary)
                    .overlay(alignment: .leading) {
                        if elapsed > 0 {
                            Capsule()
                                .fill(.secondary)
                                .frame(width: max(geo.size.width * elapsed / duration, 5))
                        }
                    }
            }
            .frame(height: 5)
            Text(verbatim: duration.formattedSecondsColon)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes]))) long")
        .accessibilityValue(elapsed > 0 ? "\((duration - elapsed).formattedSeconds) remaining" : "")
    }
}

/// Where the video currently is (now playing, queue, inbox) and what's set on it
struct VideoDetailStatusIcons: View {
    @Environment(PlayerManager.self) private var player

    let video: Video

    var body: some View {
        HStack(spacing: 10) {
            ForEach(statuses, id: \.systemImage) { status in
                Label {
                    status.title
                } icon: {
                    Image(systemName: status.systemImage)
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private struct Status {
        let title: Text
        let systemImage: String
    }

    private var statuses: [Status] {
        var statuses = [Status]()
        let isPlaying = video.youtubeId == player.video?.youtubeId
        if isPlaying {
            statuses.append(Status(title: Text("nowPlaying"), systemImage: "play.fill"))
        }
        // the playing video sits at the top of the queue; its position says nothing there
        if let order = video.queueEntry?.order, !isPlaying || order != 0 {
            statuses.append(Status(
                title: order == 0 ? Text("queue") : Text("queuePosition \(order)"),
                systemImage: "arrow.uturn.right"
            ))
        }
        if video.inboxEntry != nil {
            statuses.append(Status(title: Text("inbox"), systemImage: "tray.fill"))
        }
        if let deferDate = video.deferDate {
            statuses.append(Status(
                title: Text("deferredUntil \(deferDate.formatted(date: .abbreviated, time: .shortened))"),
                systemImage: "clock.fill"
            ))
        }
        if video.isNew {
            statuses.append(Status(title: Text("statusNew"), systemImage: "circle.fill"))
        }
        if video.bookmarkedDate != nil {
            statuses.append(Status(title: Text("bookmarked"), systemImage: "bookmark.fill"))
        }
        if let watchedDate = video.watchedDate {
            statuses.append(Status(
                title: Text("watchedOn \(watchedDate.formatted(date: .abbreviated, time: .omitted))"),
                systemImage: "checkmark"
            ))
        }
        if video.downloadedDate != nil {
            statuses.append(Status(title: Text("downloaded"), systemImage: "arrow.down"))
        }
        return statuses
    }
}

#Preview {
    DescriptionDetailView(description: Video.getDummy().description)
        .previewEnvironments()
}
