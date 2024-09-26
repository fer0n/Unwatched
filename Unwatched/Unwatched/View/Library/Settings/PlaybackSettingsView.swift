//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlaybackSettingsView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = false
    @AppStorage(Const.rotateOnPlay) var rotateOnPlay: Bool = false
    @AppStorage(Const.swapNextAndContinuous) var swapNextAndContinuous: Bool = false
    @AppStorage(Const.enableYtWatchHistory) var enableYtWatchHistory: Bool = true

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                if UIDevice.supportsFullscreenControls {
                    MySection(footer: "showFullscreenControlsHelper") {
                        Picker("fullscreenControls", selection: $fullscreenControlsSetting) {
                            Text(FullscreenControls.autoHide.description)
                                .tag(FullscreenControls.autoHide)
                            Text(FullscreenControls.enabled.description)
                                .tag(FullscreenControls.enabled)
                            if UIDevice.isIphone {
                                Text(FullscreenControls.disabled.description)
                                    .tag(FullscreenControls.disabled)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                MySection {
                    Toggle(isOn: $hideMenuOnPlay) {
                        Text("hideMenuOnPlay")
                    }

                    Toggle(isOn: $returnToQueue) {
                        Text("returnToQueue")
                    }

                    if UIDevice.isIphone {
                        Toggle(isOn: $rotateOnPlay) {
                            Text("rotateOnPlay")
                        }
                    }
                }

                MySection(footer: "swapNextAndContinuousHelper") {
                    Toggle(isOn: $swapNextAndContinuous) {
                        Text("swapNextAndContinuous")
                    }
                }

                MySection("youtube", footer: "enableYtWatchHistoryHelper") {
                    Toggle(isOn: $enableYtWatchHistory) {
                        Text("enableYtWatchHistory")
                    }
                    .onChange(of: enableYtWatchHistory) { _, _ in
                        PlayerManager.reloadPlayer()
                    }
                }

                MySection {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }

            }
            .myNavigationTitle("playback")
        }
    }
}

#Preview {
    PlaybackSettingsView()
}
