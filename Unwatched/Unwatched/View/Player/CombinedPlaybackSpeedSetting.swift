//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSettingPlayer: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @Environment(PlayerManager.self) var player

    @State var hapticToggle: Bool = false
    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var isExpanded = false
    var hasHaptics = true
    var hasSmallestSize: Bool = false

    var body: some View {
        @Bindable var player = player
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
            hapticToggle.toggle()
        })

        CombinedPlaybackSpeedSetting(
            selectedSpeed: $player.playbackSpeed,
            isOn: isOn,
            hapticToggle: $hapticToggle,
            hasHaptics: hasHaptics,
            spacing: spacing,
            showTemporarySpeed: showTemporarySpeed,
            isExpanded: isExpanded,
            hasSmallestSize: hasSmallestSize
        )
        .disabled(player.video?.subscription == nil)
        .onChange(of: player.video?.subscription) {
            // workaround
        }
    }
}

struct CombinedPlaybackSpeedSetting: View {
    @Environment(PlayerManager.self) var player

    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool
    @Binding var hapticToggle: Bool
    var hasHaptics = true

    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var isExpanded = false
    var hasSmallestSize: Bool = false

    var body: some View {
        HStack(spacing: spacing) {
            if isExpanded {
                VStack {
                    SpeedControlView(
                        selectedSpeed: $selectedSpeed,
                        hasSmallestSize: hasSmallestSize
                    )
                    CustomSettingsButton(isOn: $isOn)
                        .tint(Color.foregroundGray.opacity(0.5))
                        .padding(.horizontal, 2)
                }
                .padding(.vertical)
            } else {
                HStack(spacing: -6) {
                    SpeedControlView(
                        selectedSpeed: $selectedSpeed,
                        hasSmallestSize: hasSmallestSize
                    )
                    CustomSettingsButton(isOn: $isOn)
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
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle) { _, _ in
            return hasHaptics
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
    @Previewable @State var isOn = false
    @Previewable @State var selectedSpeed: Double = 1

    CombinedPlaybackSpeedSetting(selectedSpeed: $selectedSpeed, isOn: $isOn, hapticToggle: .constant(true), isExpanded: true)
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager())
        .frame(width: 350)
}
