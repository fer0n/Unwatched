//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI

struct PlaybackSettingsView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.goToQueueOnPlay) var goToQueueOnPlay: Bool = false
    @AppStorage(Const.rotateOnPlay) var rotateOnPlay: Bool = false

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                if UIDevice.supportsFullscreenControls {
                    MySection(footer: "showFullscreenControlsHelper") {
                        Picker("fullscreenControls", selection: $fullscreenControlsSetting) {
                            ForEach(FullscreenControls.allCases, id: \.self) {
                                Text($0.description)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                MySection {
                    Toggle(isOn: $hideMenuOnPlay) {
                        Text("hideMenuOnPlay")
                    }

                    Toggle(isOn: $goToQueueOnPlay) {
                        Text("goToQueueOnPlay")
                    }

                    Toggle(isOn: $rotateOnPlay) {
                        Text("rotateOnPlay")
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
