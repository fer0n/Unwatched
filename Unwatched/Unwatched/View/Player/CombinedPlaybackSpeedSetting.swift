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
    var indicatorSpacing: CGFloat = 4

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
            indicatorSpacing: indicatorSpacing
        )
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
    var indicatorSpacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            if isExpanded {
                VStack {
                    SpeedControlView(
                        selectedSpeed: $selectedSpeed,
                        indicatorSpacing: indicatorSpacing
                    )
                    CustomSettingsButton(isOn: $isOn)
                        .tint(Color.foregroundGray.opacity(0.5))
                        .padding(.horizontal, 2)
                        .disabled(player.video?.subscription == nil)
                }
                .padding(.vertical)
            } else {
                HStack(spacing: -6) {
                    SpeedControlView(
                        selectedSpeed: $selectedSpeed,
                        indicatorSpacing: indicatorSpacing
                    )
                    CustomSettingsButton(isOn: $isOn)
                        .toggleStyle(
                            CustomSettingsToggleStyle(
                                imageOn: Const.customPlaybackSpeedSF,
                                imageOff: Const.customPlaybackSpeedOffSF
                            )
                        )
                        .offset(x: -1)
                        .disabled(player.video?.subscription == nil)

                    if showTemporarySpeed {
                        Button {
                            player.toggleTemporaryPlaybackSpeed()
                        } label: {
                            Image(systemName: "waveform")
                                .font(.title3)
                                .padding(8)
                                .speedSettingsImageStyle(
                                    isOn: player.temporaryPlaybackSpeed != nil,
                                    imageOn: "gauge.with.needle.fill",
                                    imageOff: "gauge.with.needle"
                                )
                        }
                        .buttonStyle(.plain)
                        .help("toggleTemporarySpeed")
                        .accessibilityLabel("toggleTemporarySpeed")
                    }
                }
                .background {
                    Capsule()
                        .fill(Color.backgroundColor)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle) { _, _ in
            return hasHaptics
        }
    }
}

#Preview {
    @Previewable @State var isOn = false
    @Previewable @State var selectedSpeed: Double = 1

    CombinedPlaybackSpeedSetting(
        selectedSpeed: $selectedSpeed,
        isOn: $isOn,
        hapticToggle: .constant(
            true
        ),
        showTemporarySpeed: true,
        isExpanded: false
    )
    .modelContainer(DataProvider.previewContainer)
    .environment(PlayerManager.getDummy())
    .environment(NavigationManager())
    .frame(width: 350)
}
