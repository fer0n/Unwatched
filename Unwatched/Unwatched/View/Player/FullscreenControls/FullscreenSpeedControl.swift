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
                    .presentationBackground(Const.iOS26 ? .clear : .black)
                    .presentationCompactAdaptation(.popover)
                    .fontWeight(nil)
                    .preferredColorScheme(.dark)
            }
    }

    var speedText: String {
        let speedText = SpeedHelper.formatSpeed(player.debouncedPlaybackSpeed)
        return "\(speedText)\(speedText.count <= 1 ? "×" : "")"
    }
}

struct FullscreenSpeedControl: View {
    @Namespace private var namespace
    let transitionId = "popoverTransition"

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
                #if !os(visionOS)
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundStyle(Color.backgroundColor)
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
                .foregroundStyle(Color.foregroundGray.opacity(0.5))
                #endif
            }
            #if !os(visionOS)
            .modifier(PlayerControlButtonStyle(isOn: hasCustomSetting))
            #endif
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    handleTap()
                }
        )
        .fontWeight(.medium)
        #if !os(visionOS)
        .frame(width: 35)
        #endif
        .apply {
            if #available(iOS 26.0, *) {
                $0.matchedTransitionSource(id: transitionId, in: namespace)
            } else {
                $0
            }
        }
        #if !os(visionOS)
        .padding(.horizontal) // workaround: safearea pushing content in pop over
        #endif
        .popover(isPresented: $showSpeedControl, arrowEdge: arrowEdge) {
            #if os(visionOS)
            visionPopOver
            #else
            regularPopOver
            #endif
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAction {
            handleTap()
        }
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

    func handleTap() {
        if hasTempSpeed {
            player.temporaryPlaybackSpeed = nil
        } else if !showSpeedControl && !isInteracting {
            showSpeedControl = true
            autoHideVM.keepVisible = true
        }
    }

    var regularPopOver: some View {
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
            #if os(iOS)
            .apply {
                if #available(iOS 26.0, *) {
                    $0.navigationTransition(.zoom(sourceID: transitionId, in: namespace))
                } else {
                    $0
                }
            }
        #endif
    }

    var visionPopOver: some View {
        let selectedSpeed = Binding<Double>(
            get: { player.debouncedPlaybackSpeed },
            set: { value in player.playbackSpeed = value }
        )
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? player.defaultPlaybackSpeed : nil
        })

        return CombinedPlaybackSpeedSettingVision(
            selectedSpeed: selectedSpeed,
            isOn: isOn
        )
        .presentationCompactAdaptation(.popover)
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
