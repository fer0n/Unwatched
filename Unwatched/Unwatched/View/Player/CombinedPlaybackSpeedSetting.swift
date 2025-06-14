//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSettingPlayer: View {
    @Environment(PlayerManager.self) var player

    @State var hapticToggle: Bool = false
    var spacing: CGFloat = 10
    var showTemporarySpeed = false
    var isExpanded = false
    var limitWidth = false
    var hasHaptics = true
    var indicatorSpacing: CGFloat = 4
    var isTransparent = true

    var body: some View {
        @Bindable var player = player
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? player.defaultPlaybackSpeed : nil
            hapticToggle.toggle()
        })

        CombinedPlaybackSpeedSetting(
            selectedSpeed: $player.debouncedPlaybackSpeed,
            isOn: isOn,
            hapticToggle: $hapticToggle,
            hasHaptics: hasHaptics,
            spacing: spacing,
            showTemporarySpeed: showTemporarySpeed,
            isExpanded: isExpanded,
            limitWidth: limitWidth,
            indicatorSpacing: indicatorSpacing,
            isTransparent: isTransparent
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
    var limitWidth = false
    var indicatorSpacing: CGFloat = 4
    var isTransparent = true

    var body: some View {
        HStack(spacing: spacing) {
            if limitWidth {
                CompactFullscreenSpeedControl()
            } else if isExpanded {
                VStack {
                    SpeedControlView(
                        selectedSpeed: $selectedSpeed,
                        indicatorSpacing: indicatorSpacing
                    )
                    .speedSelectionBackground(isTransparent: isTransparent)

                    CustomSettingsButton(isOn: $isOn)
                        .tint(Color.foregroundGray.opacity(0.5))
                        .padding(.horizontal, 2)
                        .disabled(player.video?.subscription == nil)
                }
                .disabled(player.temporaryPlaybackSpeed != nil)
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
                        .disabled(player.video?.subscription == nil || player.temporaryPlaybackSpeed != nil)

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
                .speedSelectionBackground(isTransparent: isTransparent)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle) { _, _ in
            return hasHaptics
        }
    }
}

struct SpeedSelectionBackgroundModifier: ViewModifier {
    let isTransparent: Bool

    func body(content: Content) -> some View {
        content
            .background {
                Capsule()
                    .fill(Color.backgroundColor.opacity(isTransparent ? 0.5 : 1))
            }
    }
}

extension View {
    public func speedSelectionBackground(isTransparent: Bool = true) -> some View {
        modifier(SpeedSelectionBackgroundModifier(isTransparent: isTransparent))
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
