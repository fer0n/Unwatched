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
        Text(verbatim: speedText)
            .font(.system(size: 17))
            .fontWidth(.compressed)
            .fontWeight(.bold)
            .playerToggleModifier(isOn: player.temporaryPlaybackSpeed != nil, isSmall: true)
            .onTapGesture {
                showSpeedControl = true
            }
            .popover(isPresented: $showSpeedControl) {
                CombinedPlaybackSpeedSettingPlayer(isExpanded: true, hasHaptics: false)
                    .padding(.horizontal)
                    .frame(width: 350)
                    .environment(\.colorScheme, .dark)
                    .presentationCompactAdaptation(.popover)
                    .fontWeight(nil)
            }
    }

    var speedText: String {
        let speedText = SpeedControlViewModel.formatSpeed(player.debouncedPlaybackSpeed)
        return "\(speedText)\(speedText.count <= 1 ? "×" : "")"
    }
}

struct FullscreenSpeedControl: View {
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
                .environment(\.colorScheme, .dark)
                .if(!Const.iOS26) { view in
                    view.presentationBackground(.ultraThinMaterial)
                }
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
