//
//  WatchChapterList.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// The chapters of what is playing: a tap jumps to one, its checkmark or a swipe leaves it out of playback.
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

    /// Like the phone's list, a tap on a chapter that is off turns it back on rather than jumping.
    private func select(_ chapter: WatchRemoteChapter) {
        guard chapter.isActive else {
            toggle(chapter)
            return
        }
        if navigator.controlsPhone {
            Task { await client.send(.setChapter(startTime: chapter.startTime)) }
        } else {
            player.seek(to: chapter.startTime)
        }
    }

    private func row(_ chapter: WatchRemoteChapter, isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            // plain, so it takes only its own taps and the rest of the row jumps
            Button {
                toggle(chapter)
            } label: {
                checkmark(chapter.isActive, isCurrent: isCurrent)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: chapter.title ?? chapter.startTime.formattedSecondsColon)
                    .font(.footnote)
                    .lineLimit(2)
                if chapter.title != nil {
                    Text(verbatim: chapter.startTime.formattedSecondsColon)
                        .font(.caption2.monospacedDigit())
                        .opacity(0.6)
                }
            }
            Spacer(minLength: 0)
        }
        // inverted, like the phone's list and the speed page's tiles that are on
        .foregroundStyle(isCurrent ? Color.black : Color.primary)
        .opacity(chapter.isActive ? 1 : 0.5)
        .contentShape(.rect)
        .onTapGesture {
            select(chapter)
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
}
