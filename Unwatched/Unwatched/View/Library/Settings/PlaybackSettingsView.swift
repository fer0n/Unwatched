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
    @AppStorage(Const.originalAudio) var originalAudio: Bool = false
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = false

    @Environment(PlayerManager.self) var player

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)
            @Bindable var player = player

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

                #if os(iOS)
                MySection {
                    Toggle(isOn: $originalAudio) {
                        Text("forceOriginalAudio")
                    }
                    .onChange(of: originalAudio) { _, _ in
                        PlayerManager.reloadPlayer()
                    }

                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                }
                #endif

                MySection(footer: "continuousPlayHelper") {
                    Toggle(isOn: $player.isRepeating) {
                        Text("loopVideo")
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

                HideControlsSettings()

                TemporaryPlaybackSpeedSettings()

                MySection("browserPlayback", showPremiumIndicator: true) {
                    Toggle(isOn: $playBrowserVideosInApp) {
                        Text("playBrowserVideosInApp")
                    }
                }
                .requiresPremium(!playBrowserVideosInApp)

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

#Preview {
    PlaybackSettingsView()
        .environment(PlayerManager())
}
