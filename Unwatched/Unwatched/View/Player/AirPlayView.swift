//
//  AirPlayView.swift
//  Unwatched
//

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
    }
}

struct AirPlayView: View {
    @State private var routePickerView = AVRoutePickerView()
    @State var hapticToggle = false
    let isOn: Bool

    var body: some View {
        let color = isOn ? Color.backgroundColor : Color.automaticBlack

        Button {
            guard let button = routePickerView.subviews.first(where: { $0 is UIButton }) else {
                Logger.log.info("AirPlay button not found")
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
