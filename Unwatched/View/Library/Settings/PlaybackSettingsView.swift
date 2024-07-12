//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI

struct PlaybackSettingsView: View {
    @AppStorage(Const.showFullscreenControls) var showFullscreenControls: Bool = true
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false
    @AppStorage(Const.goToQueueOnPlay) var goToQueueOnPlay: Bool = false

    var body: some View {
        ZStack {
            Color.backgroundColor.edgesIgnoringSafeArea(.all)

            MyForm {
                if UIDevice.supportsFullscreenControls {
                    MySection(footer: "showFullscreenControlsHelper") {
                        Toggle(isOn: $showFullscreenControls) {
                            Text("showFullscreenControls")
                        }
                    }
                }

                MySection {
                    Toggle(isOn: $hideMenuOnPlay) {
                        Text("hideMenuOnPlay")
                    }

                    Toggle(isOn: $goToQueueOnPlay) {
                        Text("goToQueueOnPlay")
                    }
                }

                MySection(footer: "playbackHelper") {
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
