//
//  PlaybackSettingsView.swift
//  Unwatched
//

import SwiftUI

struct PlaybackSettingsView: View {
    @AppStorage(Const.showFullscreenControls) var showFullscreenControls: Bool = true
    @AppStorage(Const.hideMenuOnPlay) var hideMenuOnPlay: Bool = true
    @AppStorage(Const.playVideoFullscreen) var playVideoFullscreen: Bool = false

    var body: some View {
        List {
            Section(footer: Text("showFullscreenControlsHelper")) {
                Toggle(isOn: $showFullscreenControls) {
                    Text("showFullscreenControls")
                }
            }

            Toggle(isOn: $hideMenuOnPlay) {
                Text("hideMenuOnPlay")
            }

            Section(footer: Text("playbackHelper")) {
                Toggle(isOn: $playVideoFullscreen) {
                    Text("startVideosInFullscreen")
                }
            }
        }
        .navigationTitle("playback")
    }
}

#Preview {
    PlaybackSettingsView()
}
