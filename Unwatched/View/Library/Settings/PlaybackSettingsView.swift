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
        List {
            Section(footer: Text("showFullscreenControlsHelper")) {
                Toggle(isOn: $showFullscreenControls) {
                    Text("showFullscreenControls")
                }
            }

            Section {
                Toggle(isOn: $hideMenuOnPlay) {
                    Text("hideMenuOnPlay")
                }

                Toggle(isOn: $goToQueueOnPlay) {
                    Text("goToQueueOnPlay")
                }
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
