//
//  WatchSpeedView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// The page to the right of the player: speed, its channel and tag overrides, and what ends an item.
struct WatchSpeedView: View {
    @Environment(WatchAudioPlayer.self) private var player
    @Environment(WatchNavigator.self) private var navigator
    @Environment(\.modelContext) private var modelContext
    @State private var client = WatchQueueClient.shared
    @AppStorage(Const.continuousPlay) private var continuousPlay = false

    private var controlsPhone: Bool {
        navigator.controlsPhone
    }

    var body: some View {
        List {
            speedRow

            channelRow

            if let speedLockTagName {
                tagRow(speedLockTagName)
            }

            actionRow
        }
    }

    // MARK: - Speed

    private var currentSpeed: Double {
        controlsPhone ? client.remoteSpeed : player.playbackSpeed
    }

    private var speeds: [Double] {
        SpeedHelper.selectable(including: currentSpeed)
    }

    /// A stepper rather than a picked-from list: 15 speeds are a long scroll on a watch.
    private var speedRow: some View {
        HStack(spacing: 0) {
            stepButton("minus", faster: false)
                .disabled(currentSpeed <= (speeds.first ?? 1))

            Text(SpeedHelper.label(currentSpeed))
                .fontWeight(.bold)
                .fontWidth(.compressed)
                .monospacedDigit()
                .frame(maxWidth: .infinity)

            stepButton("plus", faster: true)
                .disabled(currentSpeed >= (speeds.last ?? 1))
        }
        .watchTile()
        .listRowBackground(Color.clear)
        // The buttons run to the edges of the rect, corners included.
        .listRowInsets(EdgeInsets())
    }

    private func stepButton(_ symbol: String, faster: Bool) -> some View {
        Button {
            step(faster: faster)
        } label: {
            Image(systemName: symbol)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func step(faster: Bool) {
        let current = currentSpeed
        let next = faster
            ? speeds.first(where: { $0 > current })
            : speeds.last(where: { $0 < current })
        // A stored value can sit outside the stepped range; snap into it.
        setSpeed(next ?? (faster ? speeds.last : speeds.first) ?? 1)
    }

    private func setSpeed(_ value: Double) {
        if controlsPhone {
            client.setRemoteSpeed(value)
        } else {
            player.setPlaybackSpeed(value)
        }
    }

    // MARK: - Channel override

    private var hasCustomSpeed: Bool {
        controlsPhone
            ? client.remote?.hasCustomSpeed == true
            : player.video?.subscription?.customSpeedSetting != nil
    }

    private var canSetCustomSpeed: Bool {
        controlsPhone
            ? client.remote?.canSetCustomSpeed == true
            : player.video?.subscription != nil
    }

    /// Disabled rather than dropped: a row that comes and goes rebuilds the list under the thumb.
    private var channelRow: some View {
        let isOn = hasCustomSpeed
        return Button {
            setCustomSpeed(!isOn)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? Const.channelSpeedLockFillSF : Const.customPlaybackSpeedOffSF)
                Text("watchCustomSpeed")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.tilePadding)
            .watchTile(isOn: isOn)
        }
        .buttonStyle(.plain)
        .disabled(!canSetCustomSpeed)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -Self.tileRowGapFix, leading: 0, bottom: 0, trailing: 0))
    }

    // MARK: - Tag override

    private var speedLockTagName: String? {
        controlsPhone
            ? client.remote?.speedLockTagName
            : player.video.flatMap(Tag.speedLockTag(for:))?.name
    }

    private var hasTagSpeed: Bool {
        controlsPhone
            ? client.remote?.hasTagSpeed == true
            : player.video.flatMap(Tag.playbackSpeedTag(for:)) != nil
    }

    /// Only there when a tag could decide, which changes with the item rather than under the thumb. Disabled
    /// while the channel's own speed is locked: that one wins.
    private func tagRow(_ tagName: String) -> some View {
        let isOn = hasTagSpeed
        return Button {
            setTagSpeed(!isOn)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? Const.tagSpeedLockFillSF : Const.customPlaybackSpeedOffSF)
                VStack(alignment: .leading, spacing: 0) {
                    Text("watchTagSpeed")
                    Text(verbatim: tagName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.tilePadding)
            .watchTile(isOn: isOn)
        }
        .buttonStyle(.plain)
        .disabled(hasCustomSpeed)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: -Self.tileRowGapFix, leading: 0, bottom: 0, trailing: 0))
    }

    private func setTagSpeed(_ enabled: Bool) {
        if controlsPhone {
            Task { await client.send(.setTagSpeed(enabled)) }
        } else {
            player.setTagSpeedEnabled(enabled)
        }
    }

    private func setCustomSpeed(_ enabled: Bool) {
        if controlsPhone {
            Task { await client.send(.setCustomSpeed(enabled)) }
        } else {
            player.setCustomSpeedEnabled(enabled)
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 4) {
            // Trimming silence needs the phone's player; continuous play works either side.
            if controlsPhone {
                tile(
                    Const.podcastSF,
                    label: "watchTrimSilence",
                    isOn: client.remote?.trimSilence == true
                ) {
                    Task { await client.send(.setTrimSilence(client.remote?.trimSilence != true)) }
                }
                .disabled(client.remote?.canTrimSilence != true)
            }

            tile(
                Const.continuousPlaySF,
                label: "watchContinuousPlay",
                isOn: isContinuousPlayOn
            ) {
                setContinuousPlay(!isContinuousPlayOn)
            }

            tile(Const.nextVideoSF, label: "watchNext", isOn: false) {
                playNext()
            }
        }
        .listRowBackground(Color.clear)
        // Takes back the space the full-bleed row above leaves.
        .listRowInsets(EdgeInsets(top: -Self.actionRowGapFix, leading: 0, bottom: 0, trailing: 0))
    }

    private func tile(
        _ symbol: String,
        label: LocalizedStringKey,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .watchTile(isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var isContinuousPlayOn: Bool {
        controlsPhone ? client.remote?.continuousPlay == true : continuousPlay
    }

    private func setContinuousPlay(_ enabled: Bool) {
        if controlsPhone {
            Task { await client.send(.setContinuousPlay(enabled)) }
        } else {
            continuousPlay = enabled
        }
    }

    /// The queue's next entry: unlike the phone's "watched, next", this marks nothing watched.
    private func playNext() {
        if controlsPhone {
            Task { await client.send(.next) }
            return
        }
        guard let next = player.nextInQueue(in: modelContext) else { return }
        player.play(next)
        navigator.tab = .player
    }

    private static let tilePadding: CGFloat = 12
    private static let tileRowGapFix: CGFloat = 15
    private static let actionRowGapFix: CGFloat = 30
}
