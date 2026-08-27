//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlaybackSettingsView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @AppStorage(Const.markWatchedOnEnded) var markWatchedOnEnded: Bool = true
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = false
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = true
    @AppStorage(Const.rotateOnPlay) var rotateOnPlay: Bool = false
    @AppStorage(Const.autoAirplayHD) var autoAirplayHD: Bool = false
    @AppStorage(Const.originalAudio) var originalAudio: Bool = true
    @AppStorage(Const.trimSilence) var trimSilence: Bool = false
    @AppStorage(Const.trimSilenceTier) var trimSilenceTier: TrimSilenceTier = .medium
    @AppStorage(Const.playBrowserVideosInApp) var playBrowserVideosInApp: Bool = false
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.preferPlayerType) var preferPlayerType: Bool = false
    @AppStorage(Const.suggestVideos) var suggestVideos: Bool = false
    @Environment(PlayerManager.self) var player

    var body: some View {
        ZStack {
            MyBackgroundColor()
            @Bindable var player = player

            MyForm {
                #if os(iOS)
                MySection {
                    NavigationLink(value: LibraryDestination.settingsPlayerType) {
                        LabeledContent("playerType") {
                            Text(playerType.description)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #endif

                MySection(footer: "preferPlayerTypeHelper") {
                    Toggle(isOn: $preferPlayerType) {
                        Text("preferPlayerType")
                    }
                }

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

                MySection {
                    Toggle(isOn: $originalAudio) {
                        Text("forceOriginalAudio")
                    }
                    .onChange(of: originalAudio) { _, _ in
                        PlayerManager.reloadPlayer()
                    }

                    #if os(iOS)
                    Toggle(isOn: $playVideoFullscreen) {
                        Text("startVideosInFullscreen")
                    }
                    #endif
                }

                MySection(footer: "trimSilenceHelper") {
                    Toggle(isOn: Binding(
                        get: { trimSilence },
                        set: { player.setTrimSilence($0) }
                    )) {
                        Text("trimSilence")
                    }

                    if trimSilence {
                        Picker("trimSilenceTier", selection: Binding(
                            get: { trimSilenceTier },
                            set: { player.setTrimSilenceTier($0) }
                        )) {
                            ForEach(TrimSilenceTier.allCases, id: \.self) { tier in
                                Text(tier.description)
                                    .tag(tier)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                MySection(footer: "continuousPlayHelper") {
                    Toggle(isOn: $player.isRepeating) {
                        Text("loopVideo")
                    }

                    Toggle(isOn: $continuousPlay) {
                        Text("continuousPlay")
                    }
                }

                MySection(footer: "markWatchedOnEndedHelper") {
                    Toggle(isOn: $markWatchedOnEnded) {
                        Text("markWatchedOnEnded")
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

                SwipeGestureSettings()

                TemporaryPlaybackSpeedSettings()

                MySection(
                    "browserPlayback",
                    footer: "$browserPlaybackFooter",
                    showPremiumIndicator: true
                ) {
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

                MySection(footer: "suggestVideosHelper") {
                    Toggle(isOn: $suggestVideos) {
                        Text("suggestVideos")
                    }
                }
                #endif
            }
            .myNavigationTitle("playback")
        }
    }
}

#Preview {
    PlaybackSettingsView()
        .environment(PlayerManager())
}
