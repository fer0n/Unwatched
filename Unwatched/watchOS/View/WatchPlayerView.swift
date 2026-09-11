//
//  WatchPlayerView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared
import WatchKit

/// What is playing, on whichever player the wearer pointed the pages at.
struct WatchPlayerView: View {
    @Environment(WatchAudioPlayer.self) private var player
    @Environment(WatchNavigator.self) private var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Query(sort: \Tag.order) private var tags: [Tag]
    @AppStorage(Const.watchSelectedTagName) private var selectedTagName = ""
    @State private var volume = WatchVolume()
    /// What playing would start: the queue's first entry, while nothing is playing yet.
    @State private var upNext: Video?
    @State private var client = WatchQueueClient.shared
    /// Redrawn once a second so the phone's timeline moves between the states it sends.
    @State private var tick = Date.now

    private var controlsPhone: Bool {
        navigator.controlsPhone
    }

    /// Not while Always On: it redraws about once a minute, so a tick a second there is all cost.
    private var carriesPosition: Bool {
        controlsPhone && !isLuminanceReduced && display.isPlaying
    }

    private var display: WatchPlayerDisplay {
        controlsPhone
            ? WatchPlayerDisplay(phone: client.remote, at: tick)
            : WatchPlayerDisplay(local: player, upNext: upNext)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            content(display)
        }
        .tint(nil)
        .animation(.easeInOut(duration: 0.15), value: isLuminanceReduced)
        // The crown belongs to the volume control, so nothing here ever sees it turn; the bar
        // comes and goes with the volume itself instead.
        .digitalCrownAccessory {
            VolumeAccessory(
                volume: volume.volume,
                isVisible: volume.isAdjusting,
                crownOrientation: volume.crownOrientation
            )
        }
        // Always mounted, parked off the edge when idle: mounted along with the change it would
        // arrive at its resting position with no state left to move from.
        .digitalCrownAccessory(.visible)
        .onChange(of: controlsPhone, initial: true) {
            if controlsPhone {
                volume.stopLocal()
            } else {
                volume.startLocal()
            }
        }
        .onChange(of: client.remoteVolume) { _, reading in
            guard controlsPhone, let reading else { return }
            volume.update(reading.value)
        }
        // Carries the phone's last reported position forward.
        .task(id: carriesPosition) {
            guard carriesPosition else { return }
            while !Task.isCancelled {
                tick = .now
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .background {
            UpNextResolver(
                filter: QueueFilter(tag: tags.first { $0.name == selectedTagName }, in: tags),
                video: $upNext
            )
        }
    }

    private func content(_ display: WatchPlayerDisplay) -> some View {
        VStack(spacing: Self.gap) {
            // No spacers: the artwork is the only flexible thing here, so the leftover height
            // is all its own.
            artwork(display)

            title(display)

            // Always On keeps the artwork and the title only.
            if !isLuminanceReduced {
                bottom(display)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        // Into the bottom inset: the band is the paged `TabView`'s own inset for its page dots,
        // which a child cannot `ignoresSafeArea`. Short of the full inset to keep the dots clear.
        .padding(.bottom, -10)
        .overlay(alignment: .bottom) {
            VolumeControl(
                isActive: navigator.tab == .player,
                origin: controlsPhone ? .companion : .local
            )
        }
    }

    private func artwork(_ display: WatchPlayerDisplay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        return ArtworkFill(url: display.artworkUrl, isSquare: display.isSquare)
            .aspectRatio(display.isSquare ? 1 : Const.defaultVideoAspectRatio, contentMode: .fit)
            .clipShape(shape)
            .artworkBorder(shape)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The chapter's own name where there is one, with the steps either side of it.
    @ViewBuilder
    private func title(_ display: WatchPlayerDisplay) -> some View {
        if let titleText = display.title {
            HStack(spacing: 0) {
                if display.hasChapters {
                    chapterColumn(display, Const.previousChapterSF, isNext: false)
                }

                Text(display.chapterTitle ?? titleText)
                    .font(.caption.weight(.semibold))
                    .fontWidth(.compressed)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if display.hasChapters {
                    chapterColumn(display, Const.nextChapterSF, isNext: true)
                }
            }
        }
    }

    /// Both sides are built the same way, so the chevrons sit on one line whatever is under them.
    private func chapterColumn(
        _ display: WatchPlayerDisplay,
        _ symbol: String,
        isNext: Bool
    ) -> some View {
        VStack(spacing: 0) {
            chapterButton(display, symbol, isNext: isNext)
            remainingText(display)
                .opacity(isNext && !isLuminanceReduced ? 1 : 0)
        }
    }

    private func chapterButton(
        _ display: WatchPlayerDisplay,
        _ symbol: String,
        isNext: Bool
    ) -> some View {
        Button {
            perform(isNext ? .nextChapter : .previousChapter)
        } label: {
            Image(systemName: symbol)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: Self.chapterColumn, height: Self.chapterSize)
                // Reaches past the chevron through the shape, so it costs the title no width.
                .contentShape(.rect.inset(by: -Self.chapterTapOverhang))
        }
        .buttonStyle(.plain)
        .opacity(isLuminanceReduced ? 0 : (isNext && !display.hasNextChapter ? 0.5 : 1))
        .disabled(isLuminanceReduced || (isNext && !display.hasNextChapter))
    }

    /// What is left of the chapter, under the step that leaves it.
    @ViewBuilder
    private func remainingText(_ display: WatchPlayerDisplay) -> some View {
        if let remaining = display.remaining {
            Text(Duration.seconds(remaining).formatted(
                .units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 1)
                    .locale(Locale(identifier: "en_US_POSIX"))
            ))
            .font(.system(size: 9).monospacedDigit())
            .frame(width: Self.chapterColumn)
            .fontWidth(.condensed)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private func bottom(_ display: WatchPlayerDisplay) -> some View {
        if let error = display.errorMessage {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else {
            WatchPlayerControls(display: display, perform: perform)
        }
    }

    private func perform(_ action: WatchPlayerAction) {
        guard !controlsPhone else {
            Task { await client.send(action.remoteCommand) }
            return
        }
        switch action {
        case .togglePlay:
            if let upNext, player.video == nil {
                player.play(upNext)
            } else {
                player.togglePlay()
            }
        case .seek(let seconds):
            player.seek(by: seconds)
        case .previousChapter:
            player.goToPreviousChapter()
        case .nextChapter:
            player.goToNextChapter()
        }
    }

    private static let gap: CGFloat = 5
    private static let chapterSize: CGFloat = 22
    private static let chapterColumn: CGFloat = 30
    private static let chapterTapOverhang: CGFloat = 10
}

/// Reads the queue's first entry for the player to offer before anything is playing. A view of its
/// own because `@Query` takes its descriptor at init, and the tag filter is only known here.
private struct UpNextResolver: View {
    @Query private var entries: [QueueEntry]
    @Binding var video: Video?

    init(filter: QueueFilter, video: Binding<Video?>) {
        _entries = Query(filter.descriptor(limit: 1))
        _video = video
    }

    var body: some View {
        Color.clear
            .onChange(of: entries.first?.video?.persistentModelID, initial: true) {
                video = entries.first?.video
            }
    }
}
