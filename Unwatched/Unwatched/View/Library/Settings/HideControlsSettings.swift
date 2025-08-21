//
//  HideControlsSettings.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

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
