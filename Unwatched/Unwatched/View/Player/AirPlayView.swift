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
    @Environment(PlayerManager.self) var player

    var body: some View {
        let isOn = player.airplayHD
        AirPlayView(isOn: isOn)
            .playerToggleModifier(isOn: isOn, isSmall: true)
            .contextMenu {
                AirPlayHDButton()
            }
            .help("airPlay")
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "airPlay"))
    }
}

struct AirPlayView: View {
    @State private var routePickerView = AVRoutePickerView()
    @State var hapticToggle = false
    let isOn: Bool

    var body: some View {
        Button {
            guard let button = routePickerView.subviews.first(where: { $0 is UIButton }) else {
                Log.info("AirPlay button not found")
                return
            }
            hapticToggle.toggle()
            (button as? UIButton)?.sendActions(for: .touchUpInside)
        } label: {
            Image(systemName: "airplay.video")
                .fontWeight(.black)
        }
        .background {
            UIKitRoutePickerView(routePickerView: routePickerView)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

struct UIKitRoutePickerView: UIViewRepresentable {
    let routePickerView: AVRoutePickerView

    func makeUIView(context: Context) -> AVRoutePickerView {
        routePickerView.isHidden = true
        routePickerView.prioritizesVideoDevices = true
        return routePickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif
