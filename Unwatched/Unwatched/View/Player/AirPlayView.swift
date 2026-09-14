//
//  AirPlayView.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import AVKit
import UnwatchedShared
import OSLog

/// Opens the system route picker by tapping a detached `AVRoutePickerView`'s button.
///
/// Shared by the player's AirPlay button and the more menu entry that stands in for it while the
/// player type button occupies its spot. The picker view is never added to the hierarchy; it only
/// exists to be poked.
@MainActor
enum AirPlayPicker {
    private static var routePickerView: AVRoutePickerView?

    static func present() {
        if routePickerView == nil {
            let picker = AVRoutePickerView()
            picker.isHidden = true
            picker.prioritizesVideoDevices = true
            routePickerView = picker
        }
        guard let button = routePickerView?.subviews.first(where: { $0 is UIButton }) as? UIButton else {
            Log.info("AirPlay button not found")
            return
        }
        button.sendActions(for: .touchUpInside)
        Signal.interaction("Player.AirPlay")
    }
}

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
        hapticToggle.toggle()
        AirPlayPicker.present()
    }

    var isOn: Bool {
        player.airplayHD
    }
}
#endif
