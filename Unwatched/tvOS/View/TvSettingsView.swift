//
//  TvSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TvSettingsView: View {
    @AppStorage(Const.markAsWatched) var markAsWatched: Bool = false
    @AppStorage(Const.tvPlaybackMode) var playbackMode: TvPlaybackMode = .youtubeApp
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1

    private let speeds = TvSpeed.selectable

    var body: some View {
        VStack(spacing: 40) {
            Section(footer: Text(playbackMode == .inApp ? "playbackSettingHelperInApp" : "playbackSettingHelper")) {
                Picker("playbackSetting", selection: $playbackMode) {
                    ForEach(TvPlaybackMode.allCases) { mode in
                        Text(mode.label)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            if playbackMode == .inApp {
                Section(footer: Text("playbackSpeedSettingHelper")) {
                    speedSetting
                }
            }
            Section(footer: Text("markWatchedSettingHelper")) {
                Toggle("markWatchedSetting", isOn: $markAsWatched)
            }
            Spacer()
        }
        .frame(maxWidth: 800)
    }

    /// A stepper rather than a picker: 15 speeds don't fit a segmented control, and stepping is
    /// what the remote is good at.
    @ViewBuilder
    var speedSetting: some View {
        HStack(spacing: 20) {
            Text("playbackSpeed")

            Spacer()

            Button {
                setSpeed(faster: false)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(playbackSpeed <= (speeds.first ?? 1))

            Text(verbatim: TvSpeed.label(playbackSpeed))
                .monospacedDigit()
                .frame(minWidth: 120)

            Button {
                setSpeed(faster: true)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(playbackSpeed >= (speeds.last ?? 1))
        }
    }

    private func setSpeed(faster: Bool) {
        let next = faster
            ? speeds.first(where: { $0 > playbackSpeed })
            : speeds.last(where: { $0 < playbackSpeed })
        // A stored value can sit outside the stepped range; snapping into it keeps the buttons
        // from doing nothing.
        playbackSpeed = next ?? (faster ? speeds.last : speeds.first) ?? 1
    }
}

#Preview {
    TvSettingsView()
        .environment(ImageCacheManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
