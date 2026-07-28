//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenSpeedControl: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.playerControlsSecondary) var secondary
    @Binding var autoHideVM: AutoHideVM

    @State var isInteracting = false

    let size: CGFloat

    var body: some View {
        PlayerSpeedMenu {
            label
        }
        .overlay {
            if hasTempSpeed {
                // tapping clears the temporary speed instead of opening the menu.
                // it sits on top so the speed keeps its scroll position instead of being rebuilt
                Button {
                    player.temporaryPlaybackSpeed = nil
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
        .fontWeight(.medium)
        #if !os(visionOS)
        .frame(width: 35)
        #endif
        .accessibilityLabel(accessibilityLabel)
    }

    var label: some View {
        ZStack {
            #if !os(visionOS)
            Image(systemName: "circle.fill")
                .resizable()
                .frame(width: size, height: size)
                // relies on the glass background from PlayerControlButtonStyle
                .foregroundStyle(Color.clear)
            #endif

            HStack(spacing: -3) {
                #if os(visionOS)
                if hasCustomSetting || hasTempSpeed {
                    Spacer()
                        .frame(width: 4)
                    Image(systemName: hasTempSpeed ? "waveform" : Const.customPlaybackSpeedSF)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                #endif

                FullscreenSpeedControlContent(
                    value: player.debouncedPlaybackSpeed,
                    onChange: { player.playbackSpeed = $0 },
                    triggerInteraction: { autoHideVM.setShowControls() },
                    isInteracting: Binding(
                        get: { isInteracting },
                        set: {
                            isInteracting = $0
                            autoHideVM.keepVisible = $0
                        }
                    )
                )
                .disabled(hasTempSpeed)
            }
            .animation(.default, value: hasCustomSetting)
            #if os(visionOS)
            .foregroundStyle(.primary)
            .tint(nil)
            #else
            .foregroundStyle(Color.playerControl(secondary: secondary))
            #endif
        }
        #if !os(visionOS)
        .modifier(PlayerControlButtonStyle(isOn: hasCustomSetting))
        #endif
    }

    var hasTempSpeed: Bool {
        player.temporaryPlaybackSpeed != nil
    }

    var hasCustomSetting: Bool {
        player.video?.subscription?.customSpeedSetting != nil
    }

    var accessibilityLabel: String {
        let speedText = SpeedHelper.formatSpeed(player.debouncedPlaybackSpeed)
        return String(localized: "playbackSpeed \(speedText)")
    }
}

#Preview {
    let player = PlayerManager.getDummy()

    VStack(spacing: 100) {
        FullscreenSpeedControl(autoHideVM: .constant(AutoHideVM()), size: 30)
            .modelContainer(DataProvider.previewContainer)
            .environment(player)
            .environment(NavigationManager())
        // .scaleEffect(4)

        HStack {
            Button {
                player.temporarySlowDown()
            } label: {
                Text("down")
            }
            Button {
                player.resetTemporaryPlaybackSpeed()
            } label: {
                Text("reset")
            }
            Button {
                player.temporarySpeedUp()
            } label: {
                Text("up")
            }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
        HStack(spacing: 0) {
            Color.black.frame(width: 300)
            Color.orange
        }
    }
}
