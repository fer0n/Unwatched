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
    @AppStorage(Const.autoAirplayHD) var autoAirplayHD: Bool = false

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

                MySection("onPlaySettings") {
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

                MySection {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }

                MySection(footer: "autoAirplayHDHelper") {
                    Toggle(isOn: $autoAirplayHD) {
                        Text("autoAirplayHD")
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
