//
//  FullscreenSpeedControl.swift
//  Unwatched
//

import SwiftUI

struct FullscreenSpeedControl: View {
    @Environment(PlayerManager.self) var player
    @State var showSpeedControl = false
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    var body: some View {
        let customSetting = player.video?.subscription?.customSpeedSetting != nil

        Button {
            showSpeedControl = true
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
        .popover(isPresented: $showSpeedControl) {
            ZStack {
                Color.sheetBackground
                    .scaleEffect(1.5)

                CombinedPlaybackSpeedSetting()
                    .padding(.horizontal)
                    .frame(width: 350)
            }
            .environment(\.colorScheme, .dark)
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: playbackSpeed) {
            // workaround: refresh speed
        }
        .onChange(of: player.video?.subscription) {
            // workaround: refresh speed
        }
    }
}
