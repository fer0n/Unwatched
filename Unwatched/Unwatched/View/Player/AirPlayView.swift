//
//  AirPlayView.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import AVKit
import UnwatchedShared
import OSLog

struct AirPlayViewModifier: ViewModifier {
    @Environment(PlayerManager.self) var player

    func body(content: Content) -> some View {
        content
            .playerToggleModifier(isOn: isOn, isSmall: true)
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
}

struct AirPlayButton: View {
    var body: some View {
        AirPlayView()
            .modifier(AirPlayViewModifier())
            .help("airPlay")
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "airPlay"))
    }
}

struct AirPlayView: View {
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
        } label: {
            Image(systemName: "airplay.video")
                .fontWeight(.black)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .buttonStyle(.plain)
    }
}
#endif
