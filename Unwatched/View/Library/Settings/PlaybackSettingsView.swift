//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI

struct PlaybackSettingsView: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.returnToQueue) var returnToQueue: Bool = false
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

                    Toggle(isOn: $returnToQueue) {
                        Text("returnToQueue")
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
