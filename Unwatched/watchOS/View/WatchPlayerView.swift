//
//  WatchPlayerView.swift
//  UnwatchedWatch
//

import SwiftUI
import UnwatchedShared

/// What is playing, and the three controls worth having on a wrist.
struct WatchPlayerView: View {
    @Environment(WatchAudioPlayer.self) var player
    @Environment(WatchNavigator.self) var navigator
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var isShowingSpeedSettings = false
    @State private var volume = WatchVolume()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            content
        }
        .animation(.default, value: isLuminanceReduced)
        .toolbar {
            if !isLuminanceReduced {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSpeedSettings = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingSpeedSettings) {
            SpeedSettingsView()
        }
        // The crown belongs to the volume control, so nothing here ever sees it turn; the bar
        // comes and goes with the volume itself instead.
        .digitalCrownAccessory {
            VolumeAccessory(
                volume: volume.volume,
                isVisible: volume.isAdjusting,
                crownOrientation: volume.crownOrientation
            )
        }
        // Always mounted, and parked off the edge when idle. Mounting it along with the change
        // was what killed the animation: the bar was inserted already at its resting position,
        // with no state left to move from.
        .digitalCrownAccessory(.visible)
        .task {
            volume.start()
        }
    }

    private var content: some View {
        // One gap throughout, from the stack rather than per-child padding, so the artwork, the
        // title and the controls sit at even intervals however many of them are being built.
        VStack(spacing: Self.gap) {
            // No spacers around the artwork: it is the only flexible thing in the stack, so the
            // leftover height is all its own and it centres itself inside it. With spacers it was
            // competing with them for that height and they split it three ways.
            artwork

            title

            // Always On keeps the artwork and the title and drops everything else: there is
            // nothing left to read, and not building the controls at all also drops their
            // dependency on `currentTime`, so the progress ring stops re-rendering once a second
            // behind a screen nobody is looking at.
            if !isLuminanceReduced {
                bottom
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        // The controls reach down into the bottom inset rather than stopping above it: the bezel's
        // curve is already the margin, and the inset on top of it wastes the one band of screen a
        // thumb lands on unaided. Negative padding rather than `ignoresSafeArea`, because the band
        // is the paged `TabView`'s own inset for its page dots — a parent's inset, which a child
        // cannot ignore. Short of the full inset so the dots stay clear of the buttons.
        .padding(.bottom, -10)
        // And a little into the top inset too, so the artwork sits nearer the middle of the screen
        // than the middle of what the toolbar leaves.
        .padding(.top, -5)
        // Invisible, and only while this page is showing: the queue beside it wants the crown for
        // scrolling. Outside the Always On branch, so a focus taken here is given back when the
        // wrist drops rather than held by a screen that isn't drawing.
        .overlay(alignment: .bottom) {
            VolumeControl(isActive: navigator.tab == .player)
        }
    }

    /// The current item's own artwork, in its own aspect ratio rather than filling the screen —
    /// against black it reads as the thing being played instead of a backdrop, and nothing has to
    /// be dimmed to keep text over it legible.
    ///
    /// Takes whatever height the title and the controls leave, and fits its ratio inside it.
    private var artwork: some View {
        ArtworkFill(
            url: player.video?.displayThumbnailUrl,
            isSquare: isSquare
        )
        .aspectRatio(isSquare ? 1 : Const.defaultVideoAspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSquare: Bool {
        player.video?.isAudioOnly == true
    }

    /// One line, cut off rather than wrapped: a title that grows to two lines pushes the artwork
    /// off-centre every time the item changes.
    @ViewBuilder
    private var title: some View {
        if let video = player.video {
            Text(video.title)
                .font(.caption.weight(.semibold))
                .fontWidth(.condensed)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var bottom: some View {
        if let error = player.errorMessage {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else {
            controls
        }
    }

    private var fraction: Double {
        guard let duration = player.duration, duration > 0 else { return 0 }
        return min(1, max(0, player.currentTime / duration))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            seekButton("gobackward.15", by: -15)

            Button {
                player.togglePlay()
            } label: {
                // The `.circle` variant, as the app's own play button uses: SF Symbols nudges the
                // triangle to the right inside the circle, so it does not read as left-heavy the
                // way a bare `play.fill` centred in an enclosure of ours does. Palette-rendered so
                // the circle is the black border around a white glyph.
                //
                // Loading pulses that same glyph rather than swapping in a spinner: the button
                // keeps saying what pressing it will do, and the wait reads as this button being
                // busy instead of a different control having taken its place.
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black)
                    .fontWeight(.black)
                    .frame(width: Self.playSize, height: Self.playSize)
                    // Plain `.replace` rather than the app's `.replace.magic(fallback: .replace)`:
                    // recorded off the simulator, this pair falls back to the down-up replace
                    // anyway, so the magic variant only reads as if something more were happening.
                    // The animation goes on the image rather than the tap, because `isPlaying`
                    // also turns over on its own — the item ends, or something else takes the
                    // audio session — and that should look the same as a press.
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.default, value: player.isPlaying)
                    .symbolEffect(.pulse, isActive: player.isLoading)
            }
            // The symbol is its own enclosure, so it covers any glass drawn behind it — plain
            // rather than paying for a layer nothing can see.
            .buttonStyle(.plain)
            .disabled(player.isLoading)
            .frame(width: Self.playSize, height: Self.playSize)
            .overlay {
                progressRing
            }

            seekButton("goforward.30", by: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    /// The timeline, wrapped around the button it belongs to. A plain stroke rather than a
    /// `ProgressView`: the system track is translucent and all but disappears against the artwork.
    ///
    /// Inset by half its width so it sits *on* the glass edge rather than floating outside it,
    /// which reads as the button's own border instead of a second ring around it.
    private var progressRing: some View {
        Circle()
            .inset(by: Self.ringWidth / 2)
            .stroke(.white.opacity(0.3), lineWidth: Self.ringWidth)
            .overlay {
                Circle()
                    .inset(by: Self.ringWidth / 2)
                    .trim(from: 0, to: fraction)
                    .stroke(.white, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    // Trims start at three o'clock; the top is where a clock face starts.
                    .rotationEffect(.degrees(-90))
            }
            .allowsHitTesting(false)
    }

    private func seekButton(_ symbol: String, by seconds: Double) -> some View {
        Button {
            player.seek(by: seconds)
        } label: {
            Image(systemName: symbol)
                .font(.footnote)
        }
        .frame(width: Self.seekSize, height: Self.seekSize)
    }

    /// Play/pause is the one you reach for without looking, so its enclosure is clearly the biggest
    /// thing on the screen and the two seek buttons shrink out of its way.
    private static let gap: CGFloat = 5
    private static let playSize: CGFloat = 46
    private static let seekSize: CGFloat = 32
    private static let ringWidth: CGFloat = 2
}

/// The "more" sheet: a channel-level speed override plus the speed itself, in one list rather
/// than two screens — the toggle is right above the value it turns on and off.
private struct SpeedSettingsView: View {
    @Environment(WatchAudioPlayer.self) var player

    private var speeds: [Double] {
        WatchSpeed.selectable(including: player.playbackSpeed)
    }

    var body: some View {
        List {
            if let subscription = player.video?.subscription {
                Toggle(
                    "watchCustomSpeed",
                    isOn: Binding(
                        get: { subscription.customSpeedSetting != nil },
                        set: { player.setCustomSpeedEnabled($0) }
                    )
                )
            }

            // A stepper rather than a picked-from list: 15 speeds are a long scroll on a watch,
            // and stepping is what the crown/a tap is good at.
            //
            // Two free-standing round buttons rather than a row of glyphs: on a wrist the target
            // has to be the whole enclosure, and the gap between them is what stops a thumb aimed
            // at one from landing on the other. The row carries no list background of its own so
            // the buttons read as the only tappable things in it.
            HStack(spacing: 0) {
                stepButton("minus", faster: false)
                    .disabled(player.playbackSpeed <= (speeds.first ?? 1))

                Text(WatchSpeed.label(player.playbackSpeed))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                stepButton("plus", faster: true)
                    .disabled(player.playbackSpeed >= (speeds.last ?? 1))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .navigationTitle("watchPlaybackSpeed")
    }

    private func stepButton(_ symbol: String, faster: Bool) -> some View {
        Button {
            setSpeed(faster: faster)
        } label: {
            Image(systemName: symbol)
                .font(.body)
                // The label fills the button so the tap target is the enclosure, not the glyph.
                .frame(width: Self.stepSize, height: Self.stepSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(width: Self.stepSize, height: Self.stepSize)
    }

    private static let stepSize: CGFloat = 44

    private func setSpeed(faster: Bool) {
        let current = player.playbackSpeed
        let next = faster
            ? speeds.first(where: { $0 > current })
            : speeds.last(where: { $0 < current })
        // A stored value can sit outside the stepped range; snapping into it keeps the buttons
        // from doing nothing.
        player.setPlaybackSpeed(next ?? (faster ? speeds.last : speeds.first) ?? 1)
    }
}

/// Playback speeds as the watch offers them, mirroring `TvSpeed`: the shared list goes down to
/// 0.2× and up to 3×, further than a crown/tap-driven picker on a small screen needs.
private enum WatchSpeed {
    static let selectable = Const.speeds.filter { $0 >= Const.speedMin && $0 <= Const.speedMax }

    /// The selectable speeds plus `speed` itself, which can sit outside the range when it comes
    /// from a channel's custom setting.
    static func selectable(including speed: Double) -> [Double] {
        selectable.contains(where: { isSame($0, speed) })
            ? selectable
            : (selectable + [speed]).sorted()
    }

    static func label(_ speed: Double) -> String {
        let number = floor(speed) == speed
            ? String(format: "%.0f", speed)
            : String(format: "%.1f", speed)
        return "\(number)×"
    }

    /// Speeds are stored as doubles and handed to AVKit as floats, so they need comparing with
    /// some slack rather than `==`.
    static func isSame(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
