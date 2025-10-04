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
        Button {
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
            Signal.log("Player.AirPlay", throttle: .weekly)
        } label: {
            Image(systemName: symbolname)
                .fontWeight(.black)
                .playerToggleModifier(isOn: isOn, isSmall: true)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .buttonStyle(.plain)
        .contextMenu {
            Section("autoAirplayHDHelperShort") {
                Button {
                    player.setAirplayHD(!isOn)
                } label: {
                    Text(isOn ? "airplayHDOn" : "airplayHDOff")
                }
            }
        }
    }

    var isOn: Bool {
        player.airplayHD
    }

    var symbolname: String {
        if #available(iOS 18.0, *) {
            return "airplay.video"
        } else {
            return "airplayvideo"
        }
    }
}
#endif
