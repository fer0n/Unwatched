//
//  AirPlayView.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import AVKit
import UnwatchedShared
import OSLog

struct AirPlayButton: View {
    var body: some View {
        AirPlayView()
            .help("airPlay")
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "airPlay"))
    }
}

struct AirPlayView: View {
    @Environment(PlayerManager.self) var player

    @State private var routePickerView: AVRoutePickerView?
    @State var hapticToggle = false

    var body: some View {
        Image(systemName: "airplay.audio")
            .fontWeight(.black)
            .playerToggleModifier(
                isOn: isOn,
                isSmall: true
            )
            .buttonWithMenu(
                accessibilityLabel: String(localized: "airPlay"),
                groups: [
                    MenuActionGroup(title: String(localized: "autoAirplayHDHelperShort"), [
                        MenuAction(
                            isOn
                                ? String(localized: "airplayHDOn")
                                : String(localized: "airplayHDOff")
                        ) {
                            player.setAirplayHD(!isOn)
                        }
                    ])
                ],
                onTap: handlePress
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    func handlePress() {
        if routePickerView == nil {
            let picker = AVRoutePickerView()
            picker.isHidden = true
            picker.prioritizesVideoDevices = true
            routePickerView = picker
        }
        guard let button = routePickerView?.subviews.first(where: { $0 is UIButton }) else {
            Log.info("AirPlay button not found")
            return
        }
        hapticToggle.toggle()
        (button as? UIButton)?.sendActions(for: .touchUpInside)
        Signal.log("Player.AirPlay")
    }

    var isOn: Bool {
        player.airplayHD
    }
}
#endif
