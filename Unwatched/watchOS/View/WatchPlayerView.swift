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

    private var controlsPhone: Bool {
        navigator.controlsPhone
    }

    private var display: WatchPlayerDisplay {
        controlsPhone
            ? WatchPlayerDisplay(phone: client.remote)
            : WatchPlayerDisplay(local: player, upNext: upNext)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            content(display)
        }
        .tint(nil)
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

            // Kept mounted even in Always On: removing it would shift the artwork.
            bottom(display)
        }
        // Into the bottom inset: the band is the paged `TabView`'s own inset for its page dots,
        // which a child cannot `ignoresSafeArea`. Short of the full inset to keep the dots clear.
        .padding(.bottom, -10)
        .padding(.top, -Self.topBarOverlap)
        .toolbar {
            if let title = display.chapterTitle ?? display.title {
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .lineLimit(1)
                        // fixed: unbounded, the bar drops the clock
                        .frame(width: Self.titleWidth, alignment: .leading)
                        .transaction(value: title) { $0.animation = nil }
                        // onto the clock's baseline
                        .offset(y: -10)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VolumeControl(
                isActive: navigator.tab == .player,
                origin: controlsPhone ? .companion : .local
            )
        }
    }

    private func artwork(_ display: WatchPlayerDisplay) -> some View {
        HStack(spacing: Self.chapterGap) {
            if display.hasChapters {
                chapterEdge(display, isNext: false)
            }

            fittedArtwork(display)
                .allowsHitTesting(false)

            if display.hasChapters {
                chapterEdge(display, isNext: true)
            }
        }
        .ignoresSafeArea(.container, edges: .horizontal)
    }

    private func fittedArtwork(_ display: WatchPlayerDisplay) -> some View {
        // `.fill` pushes the controls off screen for a square cover
        let shape = RoundedRectangle(cornerRadius: 8)
        return ArtworkFill(url: display.artworkUrl, isSquare: display.isSquare)
            .aspectRatio(display.isSquare ? 1 : Const.defaultVideoAspectRatio, contentMode: .fit)
            .clipShape(shape)
            .artworkBorder(shape)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chapterEdge(_ display: WatchPlayerDisplay, isNext: Bool) -> some View {
        Button {
            perform(isNext ? .nextChapter : .previousChapter)
        } label: {
            VStack(spacing: Self.remainingGap) {
                Image(systemName: isNext ? Const.nextChapterSF : Const.previousChapterSF)
                    .font(.body)
                    .fontWeight(.bold)
                if isNext && !isLuminanceReduced {
                    remainingText(display)
                        .fixedSize()
                }
            }
            // centers the chevron, not the stack, so both sides line up
            .alignmentGuide(VerticalAlignment.center) { _ in Self.chevronHeight / 2 }
            .offset(x: isNext ? Self.chevronBearing : -Self.chevronBearing)
            .frame(width: Self.chapterColumn, alignment: isNext ? .trailing : .leading)
            .frame(maxHeight: .infinity)
            .contentShape(
                .rect
                    .inset(by: -Self.chapterTapOverhang)
                    .offset(x: isNext ? -Self.chapterTapOverhang : Self.chapterTapOverhang)
            )
        }
        .buttonStyle(.plain)
        .opacity(isNext && !display.hasNextChapter ? 0.5 : 1)
        .disabled(isNext && !display.hasNextChapter)
    }

    /// What is left of the chapter, under the step that leaves it.
    private func remainingText(_ display: WatchPlayerDisplay) -> some View {
        CarriedTime(
            timeline: display.timeline,
            step: { display.timeline.secondsUntilRemainingChanges(at: $0) },
            content: { date in
                if let remaining = display.timeline.remaining(at: date) {
                    Text(Duration.seconds(remaining).formatted(
                        .units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 1)
                            .locale(Locale(identifier: "en_US_POSIX"))
                    ))
                    .font(.system(size: 9).monospacedDigit())
                    .fontWidth(.condensed)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .allowsHitTesting(false)
                }
            }
        )
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
    private static let chapterColumn: CGFloat = 18
    private static let chapterGap: CGFloat = 6
    private static let chevronBearing: CGFloat = 0.5
    /// Reaches 44 pt in from the screen edge.
    private static let chapterTapOverhang: CGFloat = (44 - chapterColumn) / 2
    private static let chevronHeight: CGFloat = 21
    private static let titleWidth: CGFloat = WKInterfaceDevice.current().screenBounds.width * 0.6
    private static let remainingGap: CGFloat = -1
    private static let topBarOverlap: CGFloat = 20
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
