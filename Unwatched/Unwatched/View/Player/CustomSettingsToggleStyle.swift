//
//  CustomSettingsToggleStyle.swift
//  Unwatched
//

import SwiftUI

struct CustomSettingsToggleStyle: ToggleStyle {
    var imageOn: String
    var imageOff: String

    func makeBody(configuration: Configuration) -> some View {
        Button(
            action: {
                configuration.isOn.toggle()
            },
            label: {
                Image(systemName: configuration.isOn ? imageOn : imageOff)
                    .speedSettingsImageStyle(
                        isOn: configuration.isOn,
                        imageOn: imageOn,
                        imageOff: imageOff
                    )
            }
        )
    }
}

struct SpeedSettingsImageStyle: ViewModifier {
    let isOn: Bool
    @ScaledMetric var size: CGFloat = 35
    let imageOn: String
    let imageOff: String

    func body(content: Content) -> some View {
        Image(systemName: isOn ? imageOn : imageOff)
            .font(.headline)
            .fontWeight(isOn ? .bold : .regular)
            .frame(maxHeight: .infinity)
            .frame(width: size)
            .foregroundStyle(Color.automaticBlack)
            .opacity(isOn ? 1 : 0.4)
            .contentTransition(.symbolEffect(.replace))
    }
}

extension View {
    func speedSettingsImageStyle(isOn: Bool, imageOn: String, imageOff: String) -> some View {
        self.modifier(SpeedSettingsImageStyle(
            isOn: isOn,
            imageOn: imageOn,
            imageOff: imageOff
        ))
    }
}
