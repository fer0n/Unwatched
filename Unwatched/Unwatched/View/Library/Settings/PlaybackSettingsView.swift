//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlaybackSettingsView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = false
    @AppStorage(Const.rotateOnPlay) var rotateOnPlay: Bool = false
    @AppStorage(Const.autoAirplayHD) var autoAirplayHD: Bool = false
    @AppStorage(Const.useNoCookieUrl) var useNoCookieUrl: Bool = false
    @AppStorage(Const.forceOriginalAudio) var forceOriginalAudio: Bool = true

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                if Device.supportsFullscreenControls {
                    MySection(footer: "showFullscreenControlsHelper") {
                        Picker("fullscreenControls", selection: $fullscreenControlsSetting) {
                            ForEach(FullscreenControls.allCases, id: \.self) { option in
                                Text(option.description)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                MySection(footer: "continuousPlayHelper") {
                    Toggle(isOn: $forceOriginalAudio) {
                        Text("forceOriginalAudio")
                    }
                    .onChange(of: forceOriginalAudio) { _, _ in
                        PlayerManager.reloadPlayer()
                    }

                    Toggle(isOn: $continuousPlay) {
                        Text("continuousPlay")
                    }
                }

                MySection("onPlaySettings") {
                    Toggle(isOn: $hideMenuOnPlay) {
                        Text("hideMenuOnPlay")
                    }

                    Toggle(isOn: $returnToQueue) {
                        Text("returnToQueue")
                    }

                    if Device.isIphone {
                        Toggle(isOn: $rotateOnPlay) {
                            Text("rotateOnPlay")
                        }
                    }
                }

                #if os(iOS)
                MySection {
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }
                #endif

                HideControlsSettings()

                #if os(iOS)
                MySection(footer: "autoAirplayHDHelper") {
                    Toggle(isOn: $autoAirplayHD) {
                        Text("autoAirplayHD")
                    }
                }
                #endif

                MySection("youtube", footer: "useNoCookieUrlHelper") {
                    Toggle(isOn: $useNoCookieUrl) {
                        Text("useNoCookieUrl")
                    }
                    .onChange(of: useNoCookieUrl) { _, _ in
                        PlayerManager.reloadPlayer()
                    }
                }
            }
            .myNavigationTitle("playback")
        }
    }
}

struct HideControlsSettings: View {
    @AppStorage(Const.disableCaptions) var disableCaptions: Bool = false
    @AppStorage(Const.minimalPlayerUI) var minimalPlayerUI: Bool = false
    @Environment(PlayerManager.self) var player

    var body: some View {
        MySection("hideControls") {
            Toggle(isOn: $disableCaptions) {
                Text("disableCaptions")
            }
            .onChange(of: disableCaptions) {
                reloadPlayer()
            }

            Toggle(isOn: $minimalPlayerUI) {
                Text("minimalPlayerUI")
            }
            .onChange(of: minimalPlayerUI) {
                reloadPlayer()
            }
        }
    }

    func reloadPlayer() {
        player.hotReloadPlayer()
    }
}

#Preview {
    PlaybackSettingsView()
}
