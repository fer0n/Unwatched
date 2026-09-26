//
//  WatchChapterList.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// The chapters of what is playing, each one a tap or a swipe from being left out of playback.
struct WatchChapterList: View {
    @Environment(WatchAudioPlayer.self) private var player
    @Environment(WatchNavigator.self) private var navigator
    @State private var client = WatchQueueClient.shared

    private var chapters: [WatchRemoteChapter] {
        navigator.controlsPhone
            ? client.remote?.chapters ?? []
            : player.chapters.map(WatchRemoteChapter.init)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                // the phone's position moves between the states it sends, so it is carried forward here
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let current = current(at: context.date)
                    List(chapters, id: \.startTime) { chapter in
                        row(chapter, isCurrent: chapter.startTime == current)
                            .id(chapter.startTime)
                    }
                }
                .onAppear {
                    // once, on open: following the playhead would move the rows under the thumb
                    if let current = current(at: .now) {
                        proxy.scrollTo(current, anchor: .center)
                    }
                }
            }
        }
    }

    private func current(at date: Date) -> Double? {
        let position = navigator.controlsPhone ? client.remote?.position(at: date) ?? 0 : player.currentTime
        return chapters.last { $0.startTime <= position }?.startTime
    }

    private func toggle(_ chapter: WatchRemoteChapter) {
        if navigator.controlsPhone {
            Task { await client.send(.setChapterActive(startTime: chapter.startTime, isActive: !chapter.isActive)) }
        } else if let local = player.chapters.first(where: { $0.startTime == chapter.startTime }) {
            player.toggleChapter(local)
        }
    }

    private func row(_ chapter: WatchRemoteChapter, isCurrent: Bool) -> some View {
        Button {
            toggle(chapter)
        } label: {
            HStack(spacing: 8) {
                checkmark(chapter.isActive, isCurrent: isCurrent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: chapter.title ?? Self.time(chapter.startTime))
                        .font(.footnote)
                        .strikethrough(!chapter.isActive)
                        .lineLimit(2)
                    if chapter.title != nil {
                        Text(verbatim: Self.time(chapter.startTime))
                            .font(.caption2.monospacedDigit())
                            .opacity(0.6)
                    }
                }
                Spacer(minLength: 0)
            }
            // inverted, like the phone's list and the speed page's tiles that are on
            .foregroundStyle(isCurrent ? Color.black : Color.primary)
            .opacity(chapter.isActive ? 1 : 0.5)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: WatchTile.radius)
                .fill(isCurrent ? Color.white : Color.gray.opacity(0.25))
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                toggle(chapter)
            } label: {
                Image(systemName: chapter.isActive ? "xmark" : "checkmark")
            }
            .tint(chapter.isActive ? .gray : .blue)
        }
    }

    /// The phone's: an empty circle when the chapter is off.
    private func checkmark(_ isOn: Bool, isCurrent: Bool) -> some View {
        Circle()
            .fill(isCurrent ? Color.black.opacity(0.15) : Color.white.opacity(0.2))
            .frame(width: 24, height: 24)
            .overlay {
                if isOn {
                    Image(systemName: Const.checkmarkSF)
                        .font(.footnote.weight(.bold))
                }
            }
    }

    private static func time(_ seconds: Double) -> String {
        let total = Int(seconds)
        let (hours, minutes, secs) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
