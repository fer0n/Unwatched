//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI

struct FullscreenSpeedControl: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false
    @Binding var menuOpen: Bool

    var arrowEdge: Edge = .trailing

    var body: some View {
        let customSetting = player.video?.subscription?.customSpeedSetting != nil

        Button {
            if !showSpeedControl {
                showSpeedControl = true
                menuOpen = true
            }
        } label: {
            HStack(spacing: 0) {
                let speedText = SpeedControlViewModel.formatSpeed(player.playbackSpeed)
                Text(verbatim: speedText)
                    .font(.custom("SFCompactDisplay-Bold", size: 16))
                if speedText.count <= 1 {
                    Text(verbatim: "×")
                        .font(.custom("SFCompactDisplay-Semibold", size: 14))
                }
            }
            .fixedSize()
            .modifier(PlayerControlButtonStyle(isOn: customSetting))
            .animation(.default, value: customSetting)
        }
        .frame(width: 35)
        .fontWeight(.bold)
        .popover(isPresented: $showSpeedControl, arrowEdge: arrowEdge) {
            ZStack {
                Color.sheetBackground
                    .scaleEffect(1.5)

                CombinedPlaybackSpeedSetting()
                    .padding(.horizontal)
                    .frame(width: 350)
            }
            .environment(\.colorScheme, .dark)
            .presentationCompactAdaptation(.popover)
            .onDisappear {
                menuOpen = false
            }
        }
        .onChange(of: playbackSpeed) {
            // workaround: refresh speed
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
    }
}
