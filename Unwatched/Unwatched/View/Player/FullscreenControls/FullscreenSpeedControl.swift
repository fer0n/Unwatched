//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class FullscreenSpeedControlVM {
    var debounceTask: Task<Void, Never>?
}

struct CompactFullscreenSpeedControl: View {
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false

    var body: some View {
        FullscreenSpeedControlContent(
            value: player.debouncedPlaybackSpeed,
            onChange: { player.playbackSpeed = $0 },
            triggerInteraction: { },
            isInteracting: .constant(false),
            animationWorkaround: true
        )
        .fontWeight(.regular)
        .playerToggleModifier(isOn: player.temporaryPlaybackSpeed != nil, isSmall: true)
        .onTapGesture {
            showSpeedControl = true
        }
        .popover(isPresented: $showSpeedControl) {
            CombinedPlaybackSpeedSettingPlayer(isExpanded: true, hasHaptics: false)
                .padding(.horizontal)
                .frame(width: 350)
                .presentationBackground(.black)
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
                .fontWeight(nil)
        }
    }
}

struct FullscreenSpeedControl: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false
    @Binding var autoHideVM: AutoHideVM

    @State var isInteracting = false

    @State var viewModel = FullscreenSpeedControlVM()
    var arrowEdge: Edge = .trailing
    @GestureState private var isDetectingLongPress = false
    let size: CGFloat

    var body: some View {
        Button {
            // nothing
        } label: {
            ZStack {
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundStyle(Color.backgroundColor)
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
                .foregroundStyle(Color.foregroundGray.opacity(0.5))
            }
            .modifier(PlayerControlButtonStyle(isOn: customSetting))
        }
        .onChange(of: playbackSpeed) {
            // workaround: refresh speed
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    if !showSpeedControl && !isInteracting {
                        showSpeedControl = true
                        autoHideVM.keepVisible = true
                    }
                }
        )
        .frame(width: 35)
        .fontWeight(.medium)
        .padding(.horizontal) // workaround: safearea pushing content in pop over
        .popover(isPresented: $showSpeedControl, arrowEdge: arrowEdge) {
            CombinedPlaybackSpeedSettingPlayer(isExpanded: true, hasHaptics: false)
                .padding(.horizontal)
                .frame(width: 350)
                .presentationBackground(.black)
                .environment(\.colorScheme, .dark)
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    autoHideVM.keepVisible = false
                }
                .fontWeight(nil)
        }
    }

    var customSetting: Bool {
        player.video?.subscription?.customSpeedSetting != nil
    }
}
