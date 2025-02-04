//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class FullscreenSpeedControlVM {
    var debounceTask: Task<Void, Never>?
}

struct FullscreenSpeedControl: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false
    @Binding var menuOpen: Bool

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
                fullscreenControlLabel
                    .foregroundStyle(Color.foregroundGray.opacity(0.5))
            }
            .modifier(PlayerControlButtonStyle(isOn: customSetting))
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    if !showSpeedControl {
                        showSpeedControl = true
                        menuOpen = true
                    }
                }
        )
        .frame(width: 35)
        .fontWeight(.medium)
        .popover(isPresented: $showSpeedControl, arrowEdge: arrowEdge) {
            ZStack {
                Color.black
                    .scaleEffect(2)

                CombinedPlaybackSpeedSettingPlayer(isExpanded: true, hasHaptics: false)
                    .padding(.horizontal)
                    .frame(width: 350)
            }
            .environment(\.colorScheme, .dark)
            .presentationCompactAdaptation(.popover)
            .onDisappear {
                menuOpen = false
            }
            .fontWeight(nil)
        }
    }

    var customSetting: Bool {
        player.video?.subscription?.customSpeedSetting != nil
    }

    var fullscreenControlLabel: some View {
        HStack(spacing: 0) {
            let speedText = SpeedControlViewModel.formatSpeed(player.playbackSpeed)
            Text(verbatim: speedText)
                .font(.custom("SFCompactDisplay-Bold", size: 17))
            if speedText.count <= 1 {
                Text(verbatim: "×")
                    .font(Font.custom("SFCompactDisplay-Bold", size: 14))
            }
        }
        .fixedSize()
        .animation(.default, value: customSetting)
        .onChange(of: playbackSpeed) {
            // workaround: refresh speed
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
    }
}
