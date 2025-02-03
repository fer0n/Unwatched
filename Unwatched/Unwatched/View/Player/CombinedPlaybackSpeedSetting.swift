//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSetting: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var isExpanded = false

    var body: some View {
        @Bindable var player = player

        HStack(spacing: spacing) {
            if isExpanded {
                VStack {
                    SpeedControlView(selectedSpeed: $player.playbackSpeed)
                    CustomSettingsButton(playbackSpeed: $playbackSpeed, player: player, hasHaptics: false)
                }
                .padding(.vertical)
            } else {
                HStack(spacing: -6) {
                    SpeedControlView(selectedSpeed: $player.playbackSpeed)
                    CustomSettingsButton(playbackSpeed: $playbackSpeed, player: player)
                        .toggleStyle(
                            CustomSettingsToggleStyle(
                                imageOn: Const.customPlaybackSpeedSF,
                                imageOff: Const.customPlaybackSpeedOffSF
                            )
                        )
                        .offset(x: -1)
                }
                .background {
                    Capsule()
                        .fill(Color.backgroundColor)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if showTemporarySpeed {
                Button {
                    player.toggleTemporaryPlaybackSpeed()
                } label: {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .playerToggleModifier(
                            isOn: player.temporaryPlaybackSpeed != nil,
                            isSmall: true
                        )
                }
                .help("toggleTemporarySpeed")
                .accessibilityLabel("toggleTemporarySpeed")
            }
        }
        .onChange(of: player.video?.subscription) {
            // workaround
        }
    }
}

struct CustomSettingsToggleStyle: ToggleStyle {
    @ScaledMetric var size: CGFloat = 35
    var imageOn: String
    var imageOff: String

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn

        Button(
            action: {
                configuration.isOn.toggle()
            },
            label: {
                Image(systemName: isOn ? imageOn : imageOff)
                    .font(.headline)
                    .fontWeight(isOn ? .bold : .regular)
                    .frame(maxHeight: .infinity)
                    .frame(width: size)
                    .foregroundStyle(Color.automaticBlack)
                    .opacity(isOn ? 1 : 0.4)
                    .contentTransition(.symbolEffect(.replace))
            }
        )
    }
}

#Preview {
    CombinedPlaybackSpeedSetting(isExpanded: true)
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager())
        .frame(width: 350)
}
