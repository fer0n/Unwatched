//
//  AirPlayHDButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AirPlayHDButton: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        let isOn = player.airplayHD

        Section("autoAirplayHDHelperShort") {
            Button {
                player.setAirplayHD(!isOn)
            } label: {
                Text(isOn ? "airplayHDOn" : "airplayHDOff")
            }
        }
    }
}
