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
        let color = isOn ? Color.backgroundColor : Color.automaticBlack

        AirPlayView(color: color)
            .playerToggleModifier(isOn: isOn, isSmall: true)
            .contextMenu {
                AirPlayHDButton()
            }
    }
}

struct AirPlayView: UIViewRepresentable {
    let color: Color

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()

        let routePickerView = AVRoutePickerView()
        routePickerView.isHidden = true // Hide the default button
        routePickerView.prioritizesVideoDevices = true

        containerView.addSubview(routePickerView)

        let customButton = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .black)
        customButton.setImage(UIImage(systemName: "airplay.video", withConfiguration: config), for: .normal)
        customButton.tintColor = UIColor(color)
        customButton.contentMode = .scaleAspectFit

        customButton.addTarget(
            context.coordinator,
            action: #selector(Coordinator.showPicker),
            for: .touchUpInside
        )

        containerView.addSubview(customButton)

        customButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            customButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            customButton.widthAnchor.constraint(equalToConstant: 45),
            customButton.heightAnchor.constraint(equalToConstant: 45)
        ])

        context.coordinator.routePickerView = routePickerView

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let button = uiView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.tintColor = UIColor(color)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator {
        weak var routePickerView: AVRoutePickerView?
        private let feedbackGenerator = UIImpactFeedbackGenerator()

        @MainActor @objc func showPicker() {
            feedbackGenerator.prepare()

            guard let button = routePickerView?.subviews.first(where: { $0 is UIButton }) else {
                Logger.log.info("AirPlay button not found")
                return
            }

            feedbackGenerator.impactOccurred(intensity: 0.6)
            (button as? UIButton)?.sendActions(for: .touchUpInside)
        }
    }
}

#Preview {
    AirPlayButton()
        .environment(PlayerManager.getDummy())
}
